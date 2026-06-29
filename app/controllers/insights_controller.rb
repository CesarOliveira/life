# Análises: correlação entre uma métrica de saúde e a aderência aos hábitos.
class InsightsController < ApplicationController
  WINDOW_DAYS = 90

  def index
    @today = Date.current
    @metrics = CrossAnalysis::METRICS
    metric = params[:metric].to_s.presence_in(@metrics) || @metrics.first
    @analysis = CrossAnalysis.new(current_account, metric, from: @today - WINDOW_DAYS, to: @today).call
    @metric_key = @analysis.metric_key
    @window_days = WINDOW_DAYS
  end
end
