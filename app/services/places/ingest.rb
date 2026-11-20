module Places
  # Grava visitas de qualquer fonte (iPhone ou Google), idempotente por
  # (conta, external_id): reenviar a mesma visita atualiza a saída em vez de duplicar.
  # Cada item: { external_id:, arrived_at:, departed_at:, latitude:, longitude:,
  #             accuracy_m:, address:, hint: }
  class Ingest
    MAX_ITEMS = 5000
    MAX_DURATION = 31.days

    Result = Struct.new(:created, :updated, :skipped, keyword_init: true)

    def initialize(account, source:)
      @account = account
      @source = source
    end

    def call(items)
      result = Result.new(created: 0, updated: 0, skipped: 0)
      touched = Set.new
      Array(items).first(MAX_ITEMS).each do |raw|
        attrs = normalize(raw)
        next result.skipped += 1 unless attrs

        visit = @account.visits.find_or_initialize_by(external_id: attrs[:external_id])
        created = visit.new_record?
        visit.assign_attributes(attrs.except(:external_id))
        next result.skipped += 1 unless visit.changed? || created

        if visit.save
          (visit.date..(visit.departed_at || Time.current).to_date).each { |d| touched << d } if visit.date >= Date.current - HabitRefresh::WINDOW
          created ? result.created += 1 : result.updated += 1
        else
          result.skipped += 1
        end
      end
      Matcher.new(@account).assign_unassigned
      HabitRefresh.call(@account, touched.to_a)
      result
    end

    private

    def normalize(raw)
      h = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      h = h.transform_keys(&:to_s)
      lat = Float(h["latitude"], exception: false)
      lng = Float(h["longitude"], exception: false)
      arrived = parse_time(h["arrived_at"])
      departed = parse_time(h["departed_at"])
      return unless GeoPoint.valid?(lat, lng) && arrived
      return if departed && (departed < arrived || departed - arrived > MAX_DURATION)
      return if arrived > 1.day.from_now

      external_id = h["external_id"].to_s.strip.first(120).presence ||
                    "#{@source}:#{arrived.to_i}:#{lat.round(4)},#{lng.round(4)}"
      {
        external_id: external_id, source: @source, arrived_at: arrived, departed_at: departed,
        date: arrived.in_time_zone.to_date, latitude: lat.round(6), longitude: lng.round(6),
        accuracy_m: Integer(h["accuracy_m"].presence || 0, exception: false)&.clamp(0, 10_000),
        address: h["address"].to_s.strip.first(300).presence, hint: h["hint"].to_s.strip.first(60).presence
      }
    end

    def parse_time(value)
      return if value.blank?

      value.is_a?(Numeric) ? Time.zone.at(value) : Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
