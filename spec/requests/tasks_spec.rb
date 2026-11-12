require "rails_helper"

RSpec.describe "Tasks", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:board) { TaskBoard.create_with_columns!(account: account, name: "Pessoal") }
  let(:todo) { board.columns.first }
  let(:done) { board.columns.last }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "suggests the default columns when there is no board yet" do
    get task_boards_path
    expect(response).to have_http_status(:ok)
    TaskBoard.default_column_names.each { |name| expect(response.body).to include(%(value="#{name}")) }
  end

  it "creates a board with custom columns and treats the last one as done" do
    post task_boards_path, params: { task_board: { name: "Casa" }, columns: ["Ideias", "", "Fazendo", "Feito"] }
    created = account.task_boards.find_by!(name: "Casa")
    expect(response).to redirect_to(task_board_path(created))
    expect(created.columns.map(&:name)).to eq(%w[Ideias Fazendo Feito])
    expect(created.columns.map(&:done)).to eq([false, false, true])
  end

  it "shows the board with its columns, tasks and other boards" do
    board.tasks.create!(account: account, task_column: todo, title: "Agendar pintor")
    TaskBoard.create_with_columns!(account: account, name: "Trabalho")
    get task_board_path(board)
    expect(response.body).to include("Agendar pintor", "Trabalho", "QA", "#1")
  end

  it "creates tasks numbered per account and comments on them" do
    post task_board_tasks_path(board), params: { task: { title: "Primeira", task_column_id: todo.id } }
    post task_board_tasks_path(board), params: { task: { title: "Segunda", description: "**Medidas:** ver https://example.com" } }
    expect(account.tasks.order(:number).pluck(:number, :title)).to eq([[1, "Primeira"], [2, "Segunda"]])

    task = account.tasks.find_by!(title: "Segunda")
    post task_task_comments_path(task), params: { task_comment: { body: "<b>orçamento</b> ok" } }
    get task_path(task)
    expect(response.body).to include("&lt;b&gt;orçamento&lt;/b&gt; ok") # texto do usuário escapado
    expect(response.body).to include(%(href="https://example.com"))
    expect(response.body).to include("<strong>Medidas:</strong>")
  end

  it "moves a task by drag and drop, reordering and marking completion" do
    first = board.tasks.create!(account: account, task_column: done, title: "Já feita", completed_at: 1.day.ago)
    task = board.tasks.create!(account: account, task_column: todo, title: "Mover")

    patch move_task_path(task, format: :json), params: { column_id: done.id, position: 0 }, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("ok" => true, "done" => true)
    expect(done.tasks.reload.map(&:title)).to eq(["Mover", "Já feita"])
    expect(task.reload.completed_at).to be_present

    patch move_task_path(task), params: { column_id: todo.id }
    expect(task.reload).to have_attributes(task_column_id: todo.id, completed_at: nil)
    expect(first.reload.position).to eq(1)
  end

  it "refuses to move a task into another account's column" do
    other = TaskBoard.create_with_columns!(account: create(:account), name: "Alheio")
    task = board.tasks.create!(account: account, task_column: todo, title: "Minha")
    patch move_task_path(task, format: :json), params: { column_id: other.columns.first.id }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(task.reload.task_column_id).to eq(todo.id)
  end

  it "customizes columns: rename, recolor, reorder, add and remove only when empty" do
    board.tasks.create!(account: account, task_column: todo, title: "Ocupa a coluna")
    patch task_board_task_column_path(board, todo), params: { task_column: { name: "Entrada", color: "violet" } }
    expect(todo.reload).to have_attributes(name: "Entrada", color: "violet")

    patch task_board_task_column_path(board, todo), params: { direction: "down" }
    expect(board.columns.reload.map(&:name).first(2)).to eq(["Em andamento", "Entrada"])

    post task_board_task_columns_path(board), params: { task_column: { name: "Arquivo", color: "rose" } }
    expect(board.columns.reload.last.name).to eq("Arquivo")

    expect { delete task_board_task_column_path(board, todo) }.not_to change(TaskColumn, :count)
    expect { delete task_board_task_column_path(board, board.columns.last) }.to change(TaskColumn, :count).by(-1)
  end

  it "does not expose another account's board or task" do
    other = TaskBoard.create_with_columns!(account: create(:account), name: "Alheio")
    get task_board_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "deletes a board together with its tasks" do
    board.tasks.create!(account: account, task_column: todo, title: "Vai junto")
    expect { delete task_board_path(board) }.to change(account.task_boards, :count).by(-1).and change(account.tasks, :count).by(-1)
  end
end
