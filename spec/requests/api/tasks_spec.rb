require "rails_helper"

RSpec.describe "API::Tasks", type: :request do
  let(:account) { create(:account) }
  let(:headers) { { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" } }

  it "imports tasks into a board, creating board and columns, and is idempotent by external_id" do
    payload = { tasks: [
      { external_id: "trello:1", board: "Tarefas Diárias", column: "A fazer", title: "Agendar pintor", description: "Primeiro passo" },
      { external_id: "trello:2", board: "Tarefas Diárias", column: "Concluído", title: "Comprar cantoneira",
        created_at: "2026-11-08T10:00:00-03:00", comments: [{ body: "Comprei na loja X", created_at: "2026-11-09T15:00:00-03:00" }] }
    ] }.to_json

    expect { post "/api/tasks", params: payload, headers: headers }
      .to change(account.tasks, :count).by(2).and change(account.task_boards, :count).by(1)
    expect(JSON.parse(response.body)).to include("created" => 2, "updated" => 0)

    done = account.tasks.find_by!(external_id: "trello:2")
    expect(done.completed_at).to be_present
    expect(done.created_at.to_date).to eq(Date.new(2026, 11, 8))
    expect(done.comments.map(&:body)).to eq(["Comprei na loja X"])
    expect(account.task_boards.first.columns.map(&:name)).to eq(TaskBoard.default_column_names)

    expect { post "/api/tasks", params: payload, headers: headers }.not_to change(TaskComment, :count)
    expect(account.tasks.count).to eq(2)
    expect(JSON.parse(response.body)).to include("created" => 0, "updated" => 2)
  end

  it "skips entries without a title and rejects a bad token" do
    post "/api/tasks", params: { tasks: [{ board: "X" }] }.to_json, headers: headers
    expect(JSON.parse(response.body)).to include("created" => 0, "skipped" => 1)

    post "/api/tasks", params: { tasks: [] }.to_json, headers: headers.merge("Authorization" => "Bearer nope")
    expect(response).to have_http_status(:unauthorized)
  end
end
