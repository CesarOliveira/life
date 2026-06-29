# Página de Atividade: heatmap estilo "contribuições do GitHub" com filtros de
# período (3/6/12 meses, padrão 3) e seleção por ano.
class ActivityController < ApplicationController
  RANGES = { "3m" => 3, "6m" => 6, "12m" => 12 }.freeze
  DEFAULT_RANGE = "3m".freeze

  def index
    @today = Date.current
    @years = activity_years
    @year = params[:year].to_i if params[:year].present?
    @year = nil unless @year && @years.include?(@year)

    if @year
      @from = Date.new(@year, 1, 1)
      @to = Date.new(@year, 12, 31)
      @period = t("activity.period_year", year: @year)
    else
      @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
      months = RANGES[@range]
      @to = @today
      @from = @today << months
      @period = t("activity.period_months", count: months)
    end

    @graph = ContributionGraph.new(current_account, from: @from, to: @to, today: @today)
  end

  private

  # Anos com atividade (do primeiro check até hoje), do mais recente ao mais antigo.
  def activity_years
    first_date = HabitCheck.joins(:habit)
                           .where(habits: { account_id: current_account.id })
                           .minimum(:date)
    (((first_date || @today).year)..@today.year).to_a.reverse
  end
end
