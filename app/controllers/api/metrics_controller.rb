module Api
  # POST /api/metrics — ingestão de métricas de saúde (sono, passos, FC…) via
  # token pessoal. Pensado para um Atalho do iPhone (saúde) ou outro coletor.
  # Corpo JSON:
  #   { "date": "2026-06-28",  # ou "period": "yesterday"/"today"
  #     "metrics": [ { "key": "sleep_minutes", "value": 437 },
  #                  { "key": "steps", "value": 8021 } ] }
  # `value` pode ser número JSON ou texto (entende "1.234,5" pt-BR). A categoria,
  # a unidade e a faixa de referência saem do catálogo (Measurement::CATALOG)
  # quando não vierem no payload. Upsert idempotente por (account, key, date).
  class MetricsController < BaseController
    MAX_ENTRIES = 500

    def create
      data = parsed_body
      return render_error("invalid_payload") unless data.is_a?(Hash)

      default_date = default_date_from(data)
      metrics = coerce_list(data["metrics"])
      return render_error("invalid_payload") unless metrics.is_a?(Array)
      return render_error("too_many_entries", max: MAX_ENTRIES) if metrics.size > MAX_ENTRIES

      rows = []
      skipped = 0
      metrics.each do |entry|
        row = build_row(entry, default_date)
        row ? rows << row : skipped += 1
      end

      rows = rows.reverse.uniq { |r| [r[:key], r[:measured_on]] }.reverse
      if rows.any?
        Measurement.upsert_all(rows, unique_by: :idx_measurements_unique, record_timestamps: true)
        HabitRuleEvaluator.new(current_account).evaluate(rows.map { |r| r[:measured_on] })
      end

      render json: { ok: true, upserted: rows.size, skipped: skipped }
    end

    private

    def build_row(entry, default_date)
      return nil unless entry.is_a?(Hash)

      key = entry["key"].to_s.strip.first(60).presence
      return nil if key.blank? || !numeric?(entry["value"])

      date = parse_date(entry["measured_on"] || entry["date"] || default_date)
      return nil if date.nil? || !date_in_window?(date)

      meta = Measurement.meta(key)
      {
        account_id: current_account.id,
        key: key,
        value: numeric(entry["value"]),
        unit: entry["unit"].to_s.strip.first(20).presence || meta[:unit],
        measured_on: date,
        category: (entry["category"].presence || meta[:category] || "health").to_s,
        ref_low: entry["ref_low"].presence || meta[:ref_low],
        ref_high: entry["ref_high"].presence || meta[:ref_high],
        source: "api"
      }
    end

    def numeric?(value)
      value.is_a?(Numeric) || value.to_s.strip.match?(/\A-?\d[\d.,]*\z/)
    end

    # Aceita número JSON e texto pt-BR ("1.234,5") ou simples ("437", "7.5").
    def numeric(value)
      return value.to_f if value.is_a?(Numeric)

      str = value.to_s.strip
      str = if str.include?(".") && str.include?(",")
              str.delete(".").tr(",", ".")
      elsif str.include?(",")
              str.tr(",", ".")
      else
              str
      end
      str.to_f
    end
  end
end
