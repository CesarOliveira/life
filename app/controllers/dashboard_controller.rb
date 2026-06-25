class DashboardController < ApplicationController
  def index
    @today = Date.current
    @habits = current_account.habits.active.ordered.includes(:habit_checks).to_a
    @stats = @habits.to_h { |h| [h, HabitStats.new(h, today: @today)] }
    @today_habits = @habits.select { |h| @stats[h].scheduled_today? }
    @today_done = @today_habits.count { |h| @stats[h].done_today? }
    @best_streak = @stats.values.map(&:current_streak).max || 0
    @graph = ContributionGraph.new(current_account, today: @today)
  end
end
