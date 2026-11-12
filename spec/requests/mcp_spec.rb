require "rails_helper"

RSpec.describe "MCP server", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user).tap(&:enable_mcp!) }
  let(:yesterday) { Date.current - 1 }

  def rpc(method, params = nil, id: 1, token: account.mcp_token)
    body = { jsonrpc: "2.0", id: id, method: method, params: params }.compact
    post "/mcp/#{token}", params: body.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    response.body.present? ? JSON.parse(response.body) : nil
  end

  def tool(name, arguments = {})
    result = rpc("tools/call", { name: name, arguments: arguments })["result"]
    [result, result["isError"] ? result["content"][0]["text"] : JSON.parse(result["content"][0]["text"])]
  end

  it "rejects unknown tokens, the ingestion token and disabled access" do
    post "/mcp/nope", params: "{}"
    expect(response).to have_http_status(:unauthorized)
    post "/mcp/#{account.api_token}", params: "{}"
    expect(response).to have_http_status(:unauthorized)

    token = account.mcp_token
    account.disable_mcp!
    rpc("ping", token: token)
    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts the token as a Bearer header too" do
    post "/mcp", params: { jsonrpc: "2.0", id: 7, method: "ping" }.to_json,
                 headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{account.mcp_token}" }
    expect(JSON.parse(response.body)).to eq("jsonrpc" => "2.0", "id" => 7, "result" => {})
  end

  it "speaks the MCP handshake: initialize, initialized notification, tools/list" do
    init = rpc("initialize", { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "spec", version: "1" } })
    expect(init["result"]).to include("protocolVersion" => "2025-03-26")
    expect(init["result"]["capabilities"]).to have_key("tools")
    expect(init["result"]["serverInfo"]["name"]).to eq("life")

    post "/mcp/#{account.mcp_token}", params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json
    expect(response).to have_http_status(:accepted)
    expect(response.body).to be_empty

    tools = rpc("tools/list")["result"]["tools"]
    expect(tools.map { |t| t["name"] }).to include("get_overview", "get_screen_time", "get_health_metrics", "get_tasks", "get_exams")
    expect(tools).to all(include("inputSchema", "description"))
    expect(tools.map { |t| t.dig("annotations", "readOnlyHint") }).to all(be(true))

    expect(rpc("resources/list")["error"]["code"]).to eq(-32_601)
    get "/mcp/#{account.mcp_token}"
    expect(response).to have_http_status(:method_not_allowed)
  end

  it "returns data across all areas and never another account's" do
    create(:app_usage, account: account, bundle_id: "Instagram", name: "Instagram", date: yesterday, seconds: 7200)
    create(:app_usage, account: create(:account), bundle_id: "Segredo", name: "Segredo", date: yesterday, seconds: 9999)
    { "sleep_minutes" => 430, "sleep_bedtime" => 1380, "steps" => 9000 }.each do |key, value|
      create(:measurement, account: account, key: key, value: value, category: "health", measured_on: yesterday)
    end
    Workout.create!(account: account, uuid: "w1", activity: "running", started_at: yesterday.to_time.change(hour: 7), date: yesterday,
                    duration_seconds: 1800, distance_m: 5000)
    board = TaskBoard.create_with_columns!(account: account, name: "Pessoal")
    task = board.tasks.create!(account: account, task_column: board.columns.first, title: "Agendar pintor", creator: user)
    task.comments.create!(body: "Ligar amanhã")
    TaskMover.new(board.tasks.create!(account: account, task_column: board.columns.first, title: "Feita")).call(column: board.columns.last)

    _, overview = tool("get_overview")
    expect(overview["screen_time"]).to include("average_minutes_per_day" => 120)
    expect(overview["tasks"]).to include("open" => 1, "completed_in_period" => 1)
    expect(overview["data_coverage"].keys).to include("screen_time", "health", "workouts", "tasks")
    expect(overview.to_json).not_to include("Segredo")

    _, screen = tool("get_screen_time", { app: "instagram" })
    expect(screen).to include("total_minutes" => 120, "days_used" => 1)

    _, health = tool("get_health_metrics", { metrics: %w[sleep_minutes sleep_bedtime hrv] })
    by_key = health["metrics"].index_by { |m| m["key"] }
    expect(by_key["sleep_minutes"]).to include("unit" => "min", "average" => 430)
    expect(by_key["sleep_bedtime"]["daily"].values).to eq(["23:00"])
    expect(health["without_data"]).to eq(["hrv"])

    _, tasks = tool("get_tasks", { status: "all" })
    expect(tasks["open"].first).to include("title" => "Agendar pintor", "column" => "A fazer")
    expect(tasks["open"].first["comments"].first["text"]).to eq("Ligar amanhã")
    expect(tasks["done"].first["history"].last).to include("kind" => "moved", "to" => "Concluído")

    _, day = tool("get_daily_snapshot", { date: yesterday.iso8601 })
    expect(day["screen_time"]["apps"].first).to include("app" => "Instagram", "minutes" => 120)
    expect(day["workouts"].first).to include("activity" => "Corrida", "pace" => "6:00 /km")

    _, list = tool("list_health_metrics")
    expect(list["metrics"].map { |m| m["key"] }).to eq(%w[sleep_minutes sleep_bedtime steps])
  end

  it "reports bad arguments as a tool error the model can fix, and unknown tools as a protocol error" do
    result, text = tool("get_screen_time", { from: "ontem" })
    expect(result["isError"]).to be(true)
    expect(text).to include("AAAA-MM-DD")

    expect(rpc("tools/call", { name: "delete_everything", arguments: {} })["error"]["code"]).to eq(-32_602)
  end

  it "lets the owner enable, rotate and disable access from the setup page" do
    plain = create(:account, owner: user)
    create(:membership, user: user, account: plain, role: "owner", status: "active")
    sign_in user

    get setup_path
    expect(response.body).to include(I18n.t("setup.mcp.enable"))

    post enable_mcp_path
    first = plain.reload.mcp_token
    expect(first.length).to eq(40)
    get setup_path
    expect(response.body).to include("/mcp/#{first}") # endereço completo só no elemento oculto de cópia

    post enable_mcp_path
    expect(plain.reload.mcp_token).not_to eq(first)
    delete disable_mcp_path
    expect(plain.reload.mcp_token).to be_nil
  end
end
