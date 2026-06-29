class HabitChecksController < ApplicationController
  # Alterna (marca/desmarca) o check de um hábito numa data (default: hoje).
  def toggle
    habit = current_account.habits.find(params[:id])
    return redirect_back(fallback_location: habits_path, alert: t("habits.auto_locked")) if habit.auto?

    date = parse_date(params[:date])
    check = habit.habit_checks.find_by(date: date)
    check ? check.destroy : habit.habit_checks.create!(date: date)
    redirect_back fallback_location: habits_path
  end

  private

  def parse_date(raw)
    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end
end
