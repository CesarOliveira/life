module Api
  # POST /api/usage — ingestão de tempo de uso por app.
  # Fonte principal: Atalho do iPhone com a ação "Get App & Website Activity"
  # (iOS/macOS 26) → POST aqui. Corpo JSON:
  #   { "device": "iphone", "date": "2026-06-24",
  #     "apps": [ { "name": "Instagram", "minutes": 127 } ] }
  # Cada app aceita `bundle_id` E/OU `name` (se faltar bundle_id, usa o name como
  # chave — o Atalho só tem o nome do app), e `seconds` OU `minutes` (a Duration
  # do Atalho sai mais fácil em minutos). Upsert atômico (idempotente) por
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
      default_date = data["date"]
      apps = data["apps"]
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

    # Aceita `seconds` ou `minutes` (a Duration do Atalho costuma sair em minutos).
    def extract_seconds(entry)
      raw =
        if present_number?(entry["seconds"])
          entry["seconds"].to_f
        elsif present_number?(entry["minutes"])
          entry["minutes"].to_f * 60
        else
          0
        end
      raw.round.clamp(0, MAX_SECONDS)
    end

    def present_number?(value)
      !value.nil? && value.to_s.strip.present?
    end

    def parsed_body
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
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
