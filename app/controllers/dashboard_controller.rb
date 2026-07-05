# Dashboard (única página de visão geral): saudação + números do dia, grade de
# atividade anualizada (estilo GitHub, com seletor de ano), radar por categoria
# e hábitos de hoje. (Absorveu a antiga página Atividade.)
class DashboardController < ApplicationController
  def index
    @today = Date.current
    @habits = current_account.habits.active.ordered.includes(:habit_checks, :habit_category).to_a
    @stats = @habits.to_h { |h| [h, HabitStats.new(h, today: @today)] }
    @today_habits = @habits.select { |h| @stats[h].scheduled_today? }
    @today_done = @today_habits.count { |h| @stats[h].done_today? }
    @best_streak = @stats.values.map(&:current_streak).max || 0
    if current_account.connectors.active.exists?(kind: "github")
      @github_yesterday = current_account.measurements
                                         .find_by(key: "github_contributions", measured_on: @today - 1)&.value&.to_i
    end

    @years = activity_years
    @year = params[:year].to_i
    @year = @today.year unless @years.include?(@year)
    @from = Date.new(@year, 1, 1)
    @to = Date.new(@year, 12, 31)
    @graph = ContributionGraph.new(current_account, from: @from, to: @to, today: @today)
    load_category_stats
  end

  private

  # Anos com atividade (do primeiro check até hoje), do mais recente ao mais antigo.
  def activity_years
    first_date = HabitCheck.joins(:habit)
                           .where(habits: { account_id: current_account.id })
                           .minimum(:date)
    (((first_date || @today).year)..@today.year).to_a.reverse
  end

  # Conclusões por categoria no ano (radar). Eixos: todas as categorias da
  # conta + "Sem categoria" quando houver checks de hábitos não categorizados.
  def load_category_stats
    raw = HabitCheck.left_outer_joins(habit: :habit_category)
                    .where(habits: { account_id: current_account.id }, date: @from..@to)
                    .group("habit_categories.name").count
    @category_total = raw.values.sum

    axes = current_account.habit_categories.ordered.pluck(:name)
    axes << nil if raw[nil].to_i.positive?
    @category_stats = axes.map do |name|
      count = raw[name].to_i
      pct = @category_total.positive? ? (count * 100.0 / @category_total).round : 0
      { label: name || t("categories.none"), count: count, pct: pct }
    end
  end
end
