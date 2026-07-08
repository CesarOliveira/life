module Admin
  # Logs das rotas de ingestão (atalho do iPhone): corpo cru, query, resultado.
  class IngestionLogsController < BaseController
    def index
      @logs = IngestionLog.recent_first.includes(:account).limit(200)
      @count = IngestionLog.count
    end
  end
end
