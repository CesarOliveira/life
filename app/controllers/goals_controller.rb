# Metas de alvo: progresso de uma métrica (peso, exame…) até um valor-alvo.
class GoalsController < ApplicationController
  before_action :set_goal, only: [:destroy]

  def index
    load_goals
    @goal = current_account.goals.new
  end

  def create
    @goal = current_account.goals.new(goal_params)
    @goal.start_value = GoalProgress.new(@goal).current_value if @goal.start_value.blank?

    if @goal.save
      redirect_to goals_path, notice: t("flash.goals.created")
    else
      load_goals
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    redirect_to goals_path, notice: t("flash.goals.removed")
  end

  private

  def load_goals
    @goals = current_account.goals.ordered.to_a
    @progress = @goals.to_h { |goal| [goal, GoalProgress.new(goal)] }
    @metric_keys = Goal::METRIC_KEYS
  end

  def set_goal
    @goal = current_account.goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(:name, :metric_key, :start_value, :target_value, :deadline)
  end
end
