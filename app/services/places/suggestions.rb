module Places
  # Agrupa visitas sem lugar que caem perto umas das outras (~150 m) e devolve os
  # grupos com mais tempo, para a pessoa dar nome. A dica do Google ("HOME", "WORK")
  # vira sugestão de nome.
  class Suggestions
    CLUSTER_M = 150
    HINT_NAMES = { "HOME" => "Casa", "INFERRED_HOME" => "Casa", "WORK" => "Trabalho", "INFERRED_WORK" => "Trabalho" }.freeze

    Cluster = Struct.new(:lat, :lng, :seconds, :visits, :addresses, :hints, keyword_init: true) do
      def key = format("%.5f,%.5f", lat, lng)
      def address = addresses.tally.max_by(&:last)&.first
      def suggested_name = HINT_NAMES[hints.tally.max_by(&:last)&.first]
      def hours = (seconds / 3600.0).round(1)
    end

    def initialize(account, limit: 8, min_seconds: 30.minutes)
      @account = account
      @limit = limit
      @min_seconds = min_seconds
    end

    def call
      clusters = []
      @account.visits.unassigned.order(arrived_at: :desc).limit(5000).each do |v|
        c = clusters.find { |cl| GeoPoint.distance_m(cl.lat, cl.lng, v.lat, v.lng) <= CLUSTER_M }
        unless c
          c = Cluster.new(lat: v.lat, lng: v.lng, seconds: 0, visits: 0, addresses: [], hints: [])
          clusters << c
        end
        c.seconds += v.duration_seconds
        c.visits += 1
        c.addresses << v.address if v.address
        c.hints << v.hint if v.hint
      end
      clusters.select { |c| c.seconds >= @min_seconds }.sort_by { |c| -c.seconds }.first(@limit)
    end
  end
end
