module Api
  # POST /api/usage — ingestão de tempo de uso por app.
  # Fonte principal: Atalho do iPhone com a ação "Get App & Website Activity"
  # (iOS/macOS 26) → POST aqui. Corpo JSON:
  #   { "device": "iphone", "period": "yesterday",
  #     "apps": [ { "name": "Instagram", "duration": "2h 36min" } ] }
  # A data vem de `date` (ISO) OU de `period` ("today"/"yesterday"/"hoje"/"ontem"),
  # resolvido no fuso do app — assim o Atalho não precisa montar a data.
  # Cada app aceita `bundle_id` E/OU `name` (se faltar bundle_id, usa o name como
  # chave — o Atalho só tem o nome do app), e o tempo como `seconds`, `minutes` OU
  # `duration` (texto que a ação "Obter Atividade em Apps e Sites" devolve, ex.:
  # "2h 36min", "22min"). Upsert atômico (idempotente) por
  # (account, device, date, bundle_id): reenviar o dia sobrescreve em vez de
  # duplicar. O tempo é um snapshot do dia.
  class UsageController < BaseController
    MAX_ENTRIES = 1000
    MAX_SECONDS = 7 * 24 * 60 * 60 # sanidade: ~1 semana por linha
    DATE_WINDOW_PAST = 90 # dias

    def create
      data = parsed_body
      return render_error("invalid_payload") unless data.is_a?(Hash)

      device = data["device"].to_s.strip.first(60).presence || "iphone"
      default_date = default_date_from(data)
      apps = coerce_apps(data["apps"])
      return render_error("invalid_payload") unless apps.is_a?(Array)
      return render_error("too_many_entries", max: MAX_ENTRIES) if apps.size > MAX_ENTRIES

      rows = []
      skipped = 0
      apps.each do |entry|
        row = build_row(entry, device, default_date)
        row ? rows << row : skipped += 1
      end

      # upsert_all não aceita duplicatas na mesma chamada: mantém a última ocorrência.
      rows = rows.reverse.uniq { |r| [r[:device], r[:date], r[:bundle_id]] }.reverse
      if rows.any?
        AppUsage.upsert_all(rows, unique_by: :idx_app_usages_unique, record_timestamps: true)
        HabitRuleEvaluator.new(current_account).evaluate(rows.map { |r| r[:date] })
      end

      render json: { ok: true, upserted: rows.size, skipped: skipped }
    end

    # POST /api/usage_raw?period=yesterday&device=iphone&client_version=v11
    # "Cano burro": corpo = texto cru da ação "Obter Atividade em Apps e Sites"
    # (sem montar JSON no atalho). Tenta extrair nome+duração por linha; agrega no
    # servidor. Devolve raw_preview p/ diagnosticar o formato vindo do iPhone.
    def create_raw
      device = params[:device].to_s.strip.first(60).presence || "iphone"
      date = parse_date(default_date_from(params) || (Date.current - 1).iso8601)
      return render_error("invalid_date") if date.nil? || !date_in_window?(date)

      raw = request.raw_post.to_s.dup.force_encoding("UTF-8").scrub
      apps = parse_raw_apps(raw)
      rows = apps.filter_map { |entry| build_row(entry, device, date.iso8601) }
      rows = rows.reverse.uniq { |r| [r[:device], r[:date], r[:bundle_id]] }.reverse
      if rows.any?
        AppUsage.upsert_all(rows, unique_by: :idx_app_usages_unique, record_timestamps: true)
        HabitRuleEvaluator.new(current_account).evaluate(rows.map { |r| r[:date] })
      end

      render json: {
        ok: true, upserted: rows.size, apps: apps.size,
        client_version: params[:client_version].to_s.first(40).presence,
        raw_preview: raw[0, 400]
      }
    end

    private

    DURATION_TOKEN = /((?:\d[\d.,]*\s*(?:horas?|hr|h|min|m|seg|sec|s)\b[\s,]*)+)/i

    # Best-effort: cada linha "Nome ... <duração>" -> {name, duration}. A duração
    # é o trecho com h/min/seg; o resto da linha é o nome. (O formato exato vem do
    # raw_preview; ajusto o parser conforme o que o iPhone enviar.)
    def parse_raw_apps(raw)
      raw.split(/\r?\n/).filter_map do |line|
        line = line.gsub(/\p{Cf}/, "").strip
        next if line.empty?

        duration = line[DURATION_TOKEN, 0]
        next if duration.blank?

        name = line.sub(duration, "").gsub(/[\-–—·:,\s]+\z/, "").strip
        next if name.blank?

        { "name" => name, "duration" => duration }
      end
    end

    def build_row(entry, device, default_date)
      return nil unless entry.is_a?(Hash)

      # Remove marcas de formatação invisíveis (ex.: LRM antes de "WhatsApp").
      name = entry["name"].to_s.gsub(/\p{Cf}/, "").strip.first(120).presence
      # O Atalho do iPhone só expõe o NOME do app — sem bundle_id, usa o nome como chave.
      bundle = entry["bundle_id"].to_s.strip.first(200).presence || name
      date = parse_date(entry["date"] || default_date)
      return nil if bundle.blank? || date.nil? || !date_in_window?(date)

      {
        account_id: current_account.id,
        device: device,
        date: date,
        bundle_id: bundle,
        name: name,
        seconds: extract_seconds(entry)
      }
    end

    # Aceita `seconds`, `minutes` ou `duration` (texto da ação do iPhone).
    def extract_seconds(entry)
      raw =
        if present_number?(entry["seconds"])
          entry["seconds"].to_f
        elsif present_number?(entry["minutes"])
          entry["minutes"].to_f * 60
        elsif entry["duration"].to_s.strip.present?
          parse_duration_text(entry["duration"])
        else
          0
        end
      raw.round.clamp(0, MAX_SECONDS)
    end

    def present_number?(value)
      !value.nil? && value.to_s.strip.present?
    end

    # Entende "2h 36min" e também "9.909,861 seg" (a ação do iPhone devolve a
    # duração em segundos no formato pt-BR: "." = milhar, "," = decimal).
    def parse_duration_text(text)
      str = text.to_s.downcase
      hours = duration_part(str, /h/)
      minutes = duration_part(str, /m(?:in)?/)
      seconds = duration_part(str, /s(?:eg)?/)
      hours * 3600 + minutes * 60 + seconds
    end

    def duration_part(str, unit)
      token = str[/(\d[\d.,]*)\s*#{unit.source}/, 1]
      return 0 unless token

      token.delete(".").tr(",", ".").to_f
    end

    def parsed_body
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
    end

    # `apps` pode chegar como array, como string JSON (array ou objeto único), ou
    # como objetos JSON separados por quebra de linha — que é como o Atalhos
    # serializa a lista "Resultados de Repetição". Normaliza tudo para um array.
    def coerce_apps(value)
      return value if value.is_a?(Array)
      return nil unless value.is_a?(String)

      parsed = safe_json(value)
      return parsed if parsed.is_a?(Array)
      return [parsed] if parsed.is_a?(Hash)

      rows = value.split(/\r?\n/).filter_map { |line| safe_json(line) }
      rows.select { |row| row.is_a?(Hash) }.presence
    end

    def safe_json(str)
      return nil if str.to_s.strip.empty?

      JSON.parse(str)
    rescue JSON::ParserError
      nil
    end

    # Data padrão do lote: `date` explícito tem prioridade; senão resolve `period`
    # ("today"/"yesterday") no fuso do app, pra o Atalho não precisar montar a data.
    def default_date_from(data)
      return data["date"] if data["date"].to_s.strip.present?

      case data["period"].to_s.strip.downcase
      when "yesterday", "ontem" then (Date.current - 1).iso8601
      when "today", "hoje" then Date.current.iso8601
      end
    end

    def parse_date(raw)
      Date.iso8601(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def date_in_window?(date)
      today = Date.current
      date >= (today - DATE_WINDOW_PAST) && date <= (today + 1)
    end

    def render_error(code, **extra)
      render json: { error: code, **extra }, status: :unprocessable_entity
    end
  end
end
