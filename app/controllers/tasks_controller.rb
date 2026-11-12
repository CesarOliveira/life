class TasksController < ApplicationController
  before_action :set_task, only: [:show, :update, :destroy, :move]

  def create
    board = current_account.task_boards.find(params[:task_board_id])
    column = board.columns.find_by(id: params.dig(:task, :task_column_id)) || board.columns.first
    task = board.tasks.new(task_params.merge(account: current_account, task_column: column, creator: current_user))
    task.completed_at = Time.current if column&.done

    if task.save
      redirect_to task_board_path(board), notice: t("flash.tasks.created")
    else
      redirect_to task_board_path(board), alert: task.errors.full_messages.to_sentence
    end
  end

  def show
    @board = @task.task_board
    @columns = @board.columns.to_a
    @comment = TaskComment.new # fora da associação: não deve aparecer na lista
  end

  def update
    if @task.update(task_params)
      redirect_to task_path(@task), notice: t("flash.tasks.updated")
    else
      redirect_to task_path(@task), alert: @task.errors.full_messages.to_sentence
    end
  end

  def destroy
    board = @task.task_board
    @task.destroy
    redirect_to task_board_path(board), notice: t("flash.tasks.removed")
  end

  # Arrastar e soltar (JSON) e botões da página da tarefa (HTML).
  def move
    column = TaskColumn.joins(:task_board).where(task_boards: { account_id: current_account.id }).find_by(id: params[:column_id])
    ok = column.present? && TaskMover.new(@task).call(column: column, position: params[:position].presence, user: current_user)

    respond_to do |format|
      format.json { ok ? render(json: { ok: true, done: @task.reload.done? }) : render(json: { ok: false }, status: :unprocessable_entity) }
      format.html { redirect_to task_path(@task), (ok ? { notice: t("flash.tasks.moved") } : { alert: t("flash.tasks.move_failed") }) }
    end
  end

  private

  def set_task
    @task = current_account.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :due_on)
  end
end
