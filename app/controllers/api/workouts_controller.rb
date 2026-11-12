module Api
  # POST /api/workouts — treinos individuais do app nativo (HealthKit).
  # Corpo JSON:
  #   { "workouts": [ { "uuid": "…", "activity": "running",
  #       "start": "2026-11-11T07:02:11-03:00", "end": "2026-11-11T07:41:50-03:00",
  #       "duration": 2379, "energy_kcal": 412.3, "distance_m": 6021.4,
  #       "avg_hr": 148.2, "max_hr": 171, "source": "Apple Watch" } ] }
  # Upsert idempotente por (account, uuid): reenviar o treino sobrescreve.
  class WorkoutsController < BaseController
    after_action(only: :create) { record_ingestion("workouts") }

    MAX_ENTRIES = 500

    def create
      data = parsed_body
      list = data.is_a?(Hash) ? coerce_list(data["workouts"]) : nil
      return render_error("invalid_payload") unless list.is_a?(Array)
      return render_error("too_many_entries", max: MAX_ENTRIES) if list.size > MAX_ENTRIES

      rows = list.filter_map { |entry| build_row(entry) }
      rows = rows.reverse.uniq { |r| r[:uuid] }.reverse
      Workout.upsert_all(rows, unique_by: :idx_workouts_unique, record_timestamps: true) if rows.any?

      @ingestion_result = { upserted: rows.size, skipped: list.size - rows.size }
      render json: { ok: true, upserted: rows.size, skipped: list.size - rows.size }
    end

    private

    def build_row(entry)
      return nil unless entry.is_a?(Hash)

      uuid = entry["uuid"].to_s.strip.first(64).presence
      started = parse_timestamp(entry["start"])
      return nil if uuid.nil? || started.nil? || !date_in_window?(started.to_date)

      {
        account_id: current_account.id,
        uuid: uuid,
        activity: entry["activity"].to_s.strip.first(60).presence || "other",
        started_at: started,
        ended_at: parse_timestamp(entry["end"]),
        date: started.to_date,
        duration_seconds: entry["duration"].to_f.round.clamp(0, 7 * 86_400),
        energy_kcal: positive(entry["energy_kcal"]),
        distance_m: positive(entry["distance_m"]),
        avg_hr: positive(entry["avg_hr"]),
        max_hr: positive(entry["max_hr"]),
        source: entry["source"].to_s.strip.first(80).presence
      }
    end

    # Horário no fuso do app (o dia do treino é o dia LOCAL de início).
    def parse_timestamp(raw)
      Time.zone.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def positive(value)
      number = value.to_f
      number.positive? ? number : nil
    end
  end
end
