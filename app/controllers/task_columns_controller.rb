# Personalização das colunas de um quadro: criar, renomear, recolorir, marcar
# como "concluído", reordenar (direction=up/down) e excluir (só vazia).
class TaskColumnsController < ApplicationController
  before_action :set_board
  before_action :set_column, only: [:update, :destroy]

  def create
    column = @board.columns.new(column_params.merge(position: @board.columns.maximum(:position).to_i + 1))
    column.color = TaskColumn::COLORS.first if column.color.blank?
    flash_result(column.save, :column_created, column)
  end

  def update
    return reorder(params[:direction]) if params[:direction].present?

    flash_result(@column.update(column_params), :column_updated, @column)
  end

  def destroy
    if @column.tasks.exists?
      redirect_to edit_task_board_path(@board), alert: t("flash.tasks.column_not_empty")
    elsif @board.columns.count <= 1
      redirect_to edit_task_board_path(@board), alert: t("flash.tasks.column_last")
    else
      @column.destroy
      redirect_to edit_task_board_path(@board), notice: t("flash.tasks.column_removed")
    end
  end

  private

  def reorder(direction)
    columns = @board.columns.to_a
    index = columns.index(@column)
    target = direction == "up" ? index - 1 : index + 1
    if target.between?(0, columns.size - 1)
      columns[index], columns[target] = columns[target], columns[index]
      columns.each_with_index { |column, i| column.update_column(:position, i) }
    end
    redirect_to edit_task_board_path(@board)
  end

  def flash_result(ok, key, record)
    if ok
      redirect_to edit_task_board_path(@board), notice: t("flash.tasks.#{key}")
    else
      redirect_to edit_task_board_path(@board), alert: record.errors.full_messages.to_sentence
    end
  end

  def set_board
    @board = current_account.task_boards.find(params[:task_board_id])
  end

  def set_column
    @column = @board.columns.find(params[:id])
  end

  def column_params
    params.require(:task_column).permit(:name, :color, :done)
  end
end
