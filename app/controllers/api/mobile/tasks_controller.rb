module Api
  module Mobile
    # POST /api/mobile/tasks { title, description? } — captura rápida de tarefa pelo
    # app: entra na primeira coluna do primeiro quadro (cria um quadro padrão se
    # a conta ainda não tiver nenhum).
    class TasksController < BaseController
      def create
        title = params[:title].to_s.strip
        return render_error("blank_title") if title.blank?

        board = current_account.task_boards.ordered.first ||
                TaskBoard.create_with_columns!(account: current_account, name: I18n.t("tasks.title"))
        task = board.tasks.create!(account: current_account, task_column: board.columns.first, creator: current_owner,
                                   title: title.first(200), description: params[:description].to_s.presence)
        render json: { ok: true, number: task.number, title: task.title, board: board.name, column: task.task_column.name }, status: :created
      end
    end
  end
end
