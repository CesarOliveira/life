# Tarefas (kanban). Índice leva ao primeiro quadro; sem quadros, mostra a
# criação com a sugestão inicial de colunas.
class TaskBoardsController < ApplicationController
  before_action :set_board, only: [:show, :edit, :update, :destroy]

  def index
    board = current_account.task_boards.ordered.first
    return redirect_to(task_board_path(board)) if board

    @board = current_account.task_boards.new
    @column_names = TaskBoard.default_column_names
    render :new
  end

  def show
    @boards = current_account.task_boards.ordered
    @columns = @board.columns.includes(tasks: :comments).to_a
    @task = @board.tasks.new
  end

  def new
    @board = current_account.task_boards.new
    @column_names = TaskBoard.default_column_names
  end

  def create
    name = params.dig(:task_board, :name).to_s.strip
    if name.blank?
      @board = current_account.task_boards.new
      @board.errors.add(:name, :blank)
      @column_names = Array(params[:columns]).presence || TaskBoard.default_column_names
      return render :new, status: :unprocessable_entity
    end

    board = TaskBoard.create_with_columns!(account: current_account, name: name.first(80), column_names: params[:columns])
    redirect_to task_board_path(board), notice: t("flash.tasks.board_created")
  end

  def edit
    @columns = @board.columns.includes(:tasks).to_a
  end

  def update
    if @board.update(params.require(:task_board).permit(:name))
      redirect_to edit_task_board_path(@board), notice: t("flash.tasks.board_updated")
    else
      @columns = @board.columns.includes(:tasks).to_a
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @board.destroy
    redirect_to task_boards_path, notice: t("flash.tasks.board_removed")
  end

  private

  def set_board
    @board = current_account.task_boards.find(params[:id])
  end
end
