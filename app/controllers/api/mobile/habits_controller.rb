module Api
  module Mobile
    # POST /api/mobile/habits/:id/toggle — marca/desmarca um hábito MANUAL (padrão: hoje).
    class HabitsController < BaseController
      def toggle
        habit = current_account.habits.find_by(id: params[:id])
        return render_error("not_found") if habit.nil?
        return render_error("automatic_habit") if habit.auto?

        date = parse_date(params[:date].presence || Date.current.iso8601)
        return render_error("invalid_date") if date.nil? || date > Date.current || date < Date.current - 30

        check = habit.habit_checks.find_by(date: date)
        check ? check.destroy : habit.habit_checks.create!(date: date)
        render json: { ok: true, id: habit.id, date: date, done: check.nil? }
      end
    end
  end
end
