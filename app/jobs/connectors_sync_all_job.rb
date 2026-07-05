# Cron (de hora em hora): dispara a sincronização de todos os conectores ativos.
class ConnectorsSyncAllJob < ApplicationJob
  queue_as :default

  def perform
    Connector.active.find_each { |c| ConnectorSyncJob.perform_later(c.id) }
  end
end
