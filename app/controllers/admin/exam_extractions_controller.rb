module Admin
  # Custos de extração de exames (import de PDF): arquivo, tokens e USD gasto.
  class ExamExtractionsController < BaseController
    def index
      @extractions = ExamExtraction.recent_first.includes(:account).limit(200)
      @total_cost = ExamExtraction.sum(:cost_usd)
      @month_cost = ExamExtraction.where(created_at: Time.current.beginning_of_month..).sum(:cost_usd)
      @count = ExamExtraction.count
    end
  end
end
