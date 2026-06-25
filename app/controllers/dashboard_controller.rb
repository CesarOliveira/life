class DashboardController < ApplicationController
  def index
    @today = Date.current
    habits = current_account.habits.active.includes(:habit_checks)
    @today_habits = habits.select { |h| h.scheduled_on?(@today) }
    @today_done = @today_habits.count { |h| h.checked_on?(@today) }
  end
end
