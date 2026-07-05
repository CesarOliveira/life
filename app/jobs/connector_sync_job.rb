# Sincroniza um conector. `full: true` = backfill do histórico (na conexão).
class ConnectorSyncJob < ApplicationJob
  queue_as :default

  def perform(connector_id, full: false)
    connector = Connector.find_by(id: connector_id)
    return if connector.nil? || connector.status == "paused"

    from = full ? Date.new(Date.current.year - connector.backfill_years, 1, 1) : Date.current - 7
    case connector.kind
    when "github"
      Connectors::GithubSync.new(connector).call(from: from, to: Date.current)
    end
  end
end
