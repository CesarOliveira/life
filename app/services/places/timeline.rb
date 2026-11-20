module Places
  # O dia de uma pessoa: visitas que tocam o dia local, com o tempo recortado ao
  # dia, e o total por lugar.
  class Timeline
    Entry = Struct.new(:visit, :seconds, :starts_before, :ends_after, keyword_init: true) do
      def name = visit.place&.name || visit.address.presence || I18n.t("places.unnamed")
    end

    attr_reader :date, :entries

    def initialize(account, date, now: Time.current)
      @date = date
      from = date.in_time_zone.beginning_of_day
      to = from + 1.day
      @entries = account.visits.includes(:place).overlapping(from, to).chronological.map do |v|
        Entry.new(visit: v, seconds: v.seconds_within(from, to, now: now),
                  starts_before: v.arrived_at < from, ends_after: v.departed_at.nil? || v.departed_at > to)
      end.select { |e| e.seconds.positive? }
    end

    def totals
      @entries.group_by(&:name).map { |name, list| [name, list.sum(&:seconds)] }.sort_by { |_, s| -s }
    end

    def empty? = @entries.empty?
  end
end
