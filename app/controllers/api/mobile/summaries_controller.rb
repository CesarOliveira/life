module Api
  module Mobile
    # GET /api/mobile/summary — dados da tela inicial nativa do app.
    class SummariesController < BaseController
      def show
        render json: MobileSummary.new(current_account, user: current_owner)
      end
    end
  end
end
