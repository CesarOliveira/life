module Connectors
  # Sincroniza as contribuições do GitHub para Measurements diários
  # (key "github_contributions"). Upsert idempotente + reavaliação dos hábitos
  # automáticos nas datas tocadas.
  class GithubSync
    KEY = "github_contributions".freeze

    def initialize(connector, client: Github)
      @connector = connector
      @client = client
    end

    # Janela padrão: últimos 7 dias (cura contribuições contadas com atraso).
    def call(from: Date.current - 7, to: Date.current)
      days = fetch_days(from, to)
      upsert(days)
      @connector.mark_synced!(days.size)
      days.size
    rescue StandardError => e
      @connector.mark_error!(e.message)
      Rails.logger.error("GithubSync(#{@connector.id}): #{e.class}: #{e.message}")
      0
    end

    private

    # A API limita 1 ano por chamada — fatia o intervalo.
    def fetch_days(from, to)
      days = []
      chunk_start = from
      while chunk_start <= to
        chunk_end = [chunk_start + 364, to].min
        days += @client.contribution_days(@connector.access_token, from: chunk_start, to: chunk_end)
        chunk_start = chunk_end + 1
      end
      days.select { |d| d[:date] >= from && d[:date] <= to }
    end

    def upsert(days)
      return if days.empty?

      rows = days.map do |d|
        { account_id: @connector.account_id, key: KEY, value: d[:count],
          unit: "contributions", measured_on: d[:date], category: "productivity", source: "connector" }
      end
      Measurement.upsert_all(rows, unique_by: :idx_measurements_unique, record_timestamps: true)
      HabitRuleEvaluator.new(@connector.account).evaluate(days.map { |d| d[:date] })
    end
  end
end
