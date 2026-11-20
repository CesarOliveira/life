module Places
  # Tempo e número de dias por lugar nomeado num período (dias locais).
  class Stats
    Row = Struct.new(:place, :seconds, :visits, :days, keyword_init: true)

    def initialize(account, from:, to:)
      @account = account
      @from = from.in_time_zone.beginning_of_day
      @to = (to + 1).in_time_zone.beginning_of_day
    end

    def rows
      by_place = Hash.new { |h, k| h[k] = Row.new(place: k, seconds: 0, visits: 0, days: Set.new) }
      @account.visits.includes(:place).where.not(place_id: nil).overlapping(@from, @to).find_each do |v|
        row = by_place[v.place]
        row.seconds += v.seconds_within(@from, @to)
        row.visits += 1
        row.days << v.date
      end
      by_place.values.sort_by { |r| -r.seconds }
    end

    # Minutos num lugar num dia local (usado pelos hábitos automáticos).
    def self.minutes_on(account, place_ids, date)
      from = date.in_time_zone.beginning_of_day
      to = from + 1.day
      account.visits.where(place_id: place_ids).overlapping(from, to).sum { |v| v.seconds_within(from, to) } / 60.0
    end
  end
end
