class HabitsController < ApplicationController
  before_action :set_habit, only: %i[edit update destroy]

  def index
    @today = Date.current
    @habits = current_account.habits.active.ordered.includes(:habit_checks).to_a
    @stats = @habits.to_h { |h| [h, HabitStats.new(h, today: @today)] }
  end

  def new
    @habit = current_account.habits.new(color: Habit::DEFAULT_COLOR, weekdays: Habit::WEEKDAYS)
  end

  def create
    @habit = current_account.habits.new(habit_params)
    if @habit.save
      redirect_to habits_path, notice: "Hábito criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(habit_params)
      redirect_to habits_path, notice: "Hábito atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy
    redirect_to habits_path, notice: "Hábito removido."
  end

  private

  def set_habit
    @habit = current_account.habits.find(params[:id])
  end

  def habit_params
    permitted = params.require(:habit)
                      .permit(:name, :description, :color, :active, :position, weekdays: [])
    if permitted.key?(:weekdays)
      permitted[:weekdays] = Array(permitted[:weekdays]).reject(&:blank?).map(&:to_i).uniq.sort
    end
    permitted
  end
end
