class HabitsController < ApplicationController
  before_action :set_habit, only: %i[show edit update destroy]

  def index
    @today = Date.current
    @habits = current_account.habits.active.ordered.includes(:habit_checks).to_a
    @stats = @habits.to_h { |h| [h, HabitStats.new(h, today: @today)] }
  end

  # Página do hábito: força, sequência e timeline (feito/perdido por dia).
  def show
    @today = Date.current
    @stats = HabitStats.new(@habit, today: @today)
    @timeline = @stats.timeline(28)
    @graph = ContributionGraph.new(current_account, habit: @habit, from: @today << 3, to: @today, today: @today)
  end

  def new
    @habit = current_account.habits.new(color: Habit::DEFAULT_COLOR, weekdays: Habit::WEEKDAYS)
  end

  def create
    @habit = current_account.habits.new(habit_params)
    if @habit.save
      redirect_to habits_path, notice: t("habits.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(habit_params)
      redirect_to habits_path, notice: t("habits.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy
    redirect_to habits_path, notice: t("habits.flash.removed")
  end

  private

  def set_habit
    @habit = current_account.habits.find(params[:id])
  end

  def habit_params
    permitted = params.require(:habit)
                      .permit(:name, :description, :color, :active, :position,
                              :frequency, :weekly_target, weekdays: [])
    permitted[:frequency] = "weekly_days" unless Habit::FREQUENCIES.include?(permitted[:frequency])

    if permitted[:frequency] == "weekly_count"
      permitted.delete(:weekdays) # dias da semana não se aplicam a Nx/semana
    else
      permitted[:weekly_target] = nil
      if permitted.key?(:weekdays)
        permitted[:weekdays] = Array(permitted[:weekdays]).reject(&:blank?).map(&:to_i).uniq.sort
      end
    end
    permitted
  end
end
