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
      unless apps.is_a?(Array)
        return render json: { error: "invalid_payload", debug: payload_debug(data) },
                      status: :unprocessable_entity
      end
      return render_error("too_many_entries", max: MAX_ENTRIES) if apps.size > MAX_ENTRIES

      rows = []
      skipped = 0
      apps.each do |entry|
        row = build_row(entry, device, default_date)
        row ? rows << row : skipped += 1
      end

      # upsert_all não aceita duplicatas na mesma chamada: mantém a última ocorrência.
      rows = rows.reverse.uniq { |r| [r[:device], r[:date], r[:bundle_id]] }.reverse
      AppUsage.upsert_all(rows, unique_by: :idx_app_usages_unique, record_timestamps: true) if rows.any?

      render json: { ok: true, upserted: rows.size, skipped: skipped }
    end

    private

    def build_row(entry, device, default_date)
      return nil unless entry.is_a?(Hash)

      name = entry["name"].to_s.strip.first(120).presence
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

    # DEBUG TEMPORÁRIO: mostra o que o Atalho mandou, pra diagnosticar o formato.
    def payload_debug(data)
      {
        data_class: data.class.name,
        apps_class: (data["apps"].class.name if data.is_a?(Hash)),
        keys: (data.keys.first(20) if data.is_a?(Hash)),
        raw: request.raw_post.to_s.first(500)
      }
    end

    # `apps` pode chegar como array OU como string JSON (o Atalhos às vezes
    # serializa a lista como texto). Aceita os dois.
    def coerce_apps(value)
      return value if value.is_a?(Array)
      return nil unless value.is_a?(String)

      parsed = begin
        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
      parsed if parsed.is_a?(Array)
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
