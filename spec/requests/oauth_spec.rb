require "rails_helper"

RSpec.describe "OAuth for MCP", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:redirect_uri) { "https://claude.ai/api/mcp/auth_callback" }
  let(:verifier) { "v" * 64 }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  before { create(:membership, user: user, account: account, role: "owner", status: "active") }

  def register(uris = [redirect_uri], name: "Claude")
    post oauth_register_path, params: { client_name: name, redirect_uris: uris }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    JSON.parse(response.body)
  end

  def authorize_params(client_id, **over)
    { response_type: "code", client_id: client_id, redirect_uri: redirect_uri, state: "xyz", scope: "life:read",
      code_challenge: challenge, code_challenge_method: "S256" }.merge(over)
  end

  # Faz o fluxo inteiro e devolve o JSON de tokens.
  def obtain_tokens(client_id)
    post oauth_authorize_path, params: authorize_params(client_id, decision: "approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri, code_verifier: verifier }
    JSON.parse(response.body)
  end

  def mcp_ping(token)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
                 headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{token}" }
    response.status
  end

  it "publishes discovery metadata that points the client to authorize, token and registration" do
    get "/.well-known/oauth-protected-resource/mcp"
    resource = JSON.parse(response.body)
    expect(resource["resource"]).to eq(mcp_url)
    expect(resource["authorization_servers"]).to eq([root_url.chomp("/")])

    get "/.well-known/oauth-authorization-server"
    server = JSON.parse(response.body)
    expect(server).to include("authorization_endpoint" => oauth_authorize_url, "token_endpoint" => oauth_token_url,
                              "registration_endpoint" => oauth_register_url, "code_challenge_methods_supported" => ["S256"],
                              "client_id_metadata_document_supported" => true)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end

  it "registers clients automatically and rejects unsafe redirect URIs" do
    client = register
    expect(response).to have_http_status(:created)
    expect(client).to include("token_endpoint_auth_method" => "none", "redirect_uris" => [redirect_uri])

    ["javascript:alert(1)", "http://evil.example/cb", "https://ok.example/cb#frag"].each do |bad|
      register([bad])
      expect(response).to have_http_status(:bad_request), bad
    end
    register(["http://localhost:8123/callback", "cursor://anysphere.cursor-mcp/oauth/callback"])
    expect(response).to have_http_status(:created)
  end

  it "sends an anonymous user to login and back to the consent screen" do
    client = register
    get oauth_authorize_path, params: authorize_params(client["client_id"])
    expect(response).to redirect_to(new_user_session_path)

    sign_in user
    get oauth_authorize_path, params: authorize_params(client["client_id"])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Claude", "claude.ai", I18n.t("oauth.approve"), I18n.t("oauth.unverified"))
  end

  it "runs the full flow: consent, code exchange with PKCE, MCP access, refresh rotation and revocation" do
    sign_in user
    client_id = register["client_id"]

    post oauth_authorize_path, params: authorize_params(client_id, decision: "approve")
    callback = URI.parse(response.location)
    query = Rack::Utils.parse_query(callback.query)
    expect("#{callback.scheme}://#{callback.host}#{callback.path}").to eq(redirect_uri)
    expect(query).to include("state" => "xyz")

    post oauth_token_path, params: { grant_type: "authorization_code", code: query["code"], client_id: client_id, redirect_uri: redirect_uri, code_verifier: verifier }
    tokens = JSON.parse(response.body)
    expect(tokens).to include("token_type" => "Bearer", "expires_in" => 3600, "scope" => "life:read")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(OauthGrant.last.attributes.values.map(&:to_s)).not_to include(tokens["access_token"], tokens["refresh_token"]) # só hashes

    expect(mcp_ping(tokens["access_token"])).to eq(200)

    # o código não serve duas vezes
    post oauth_token_path, params: { grant_type: "authorization_code", code: query["code"], client_id: client_id, redirect_uri: redirect_uri, code_verifier: verifier }
    expect(JSON.parse(response.body)["error"]).to eq("invalid_grant")

    # refresh troca o par; os antigos morrem
    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: client_id }
    renewed = JSON.parse(response.body)
    expect(mcp_ping(renewed["access_token"])).to eq(200)
    expect(mcp_ping(tokens["access_token"])).to eq(401)
    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"] }
    expect(response).to have_http_status(:bad_request)

    # aparece na página de configuração e pode ser revogado
    get setup_path
    expect(response.body).to include("Claude", I18n.t("setup.mcp.revoke"))
    delete oauth_grant_path(OauthGrant.last)
    expect(mcp_ping(renewed["access_token"])).to eq(401)
  end

  describe "write permission (life:write)" do
    let(:board) { TaskBoard.create_with_columns!(account: account, name: "Pessoal") }

    def rpc(token, method, params = nil)
      post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.compact.to_json,
                   headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{token}" }
      JSON.parse(response.body)
    end

    def call_tool(token, name, arguments)
      result = rpc(token, "tools/call", { name: name, arguments: arguments })["result"]
      [result["isError"], result["isError"] ? result["content"][0]["text"] : JSON.parse(result["content"][0]["text"])]
    end

    def tokens_with(allow_write)
      client_id = register["client_id"]
      extra = allow_write ? { allow_write: "1" } : {}
      post oauth_authorize_path, params: authorize_params(client_id, decision: "approve", scope: "life:read life:write", **extra)
      code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
      post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri, code_verifier: verifier }
      JSON.parse(response.body)
    end

    before do
      sign_in user
      board
    end

    it "is off unless the user ticks it, even if the client asks for it: write tools do not exist" do
      tokens = tokens_with(false)
      expect(tokens["scope"]).to eq("life:read")
      names = rpc(tokens["access_token"], "tools/list")["result"]["tools"].map { |t| t["name"] }
      expect(names).to include("get_tasks")
      expect(names).not_to include("create_task", "move_task")
      expect(rpc(tokens["access_token"], "tools/call", { name: "create_task", arguments: { title: "x" } })["error"]["code"]).to eq(-32_602)
      expect(account.tasks.count).to eq(0)
    end

    it "lets an authorized assistant create, edit, move and comment on tasks, attributed to the user" do
      token = tokens_with(true)["access_token"]
      tools = rpc(token, "tools/list")["result"]["tools"].index_by { |t| t["name"] }
      expect(tools["create_task"]["annotations"]).to include("readOnlyHint" => false, "destructiveHint" => false)
      expect(tools["get_tasks"]["annotations"]["readOnlyHint"]).to be(true)
      expect(tools.keys.grep(/delete|destroy|remove/)).to be_empty

      _, created = call_tool(token, "create_task", { title: "Ligar para o pintor", description: "Pedir orçamento", due_on: "2026-11-20" })
      number = created["created"]["number"]
      task = account.tasks.find_by!(number: number)
      expect(task).to have_attributes(title: "Ligar para o pintor", creator: user, due_on: Date.new(2026, 11, 20))
      expect(task.task_column.name).to eq("A fazer")

      call_tool(token, "update_task", { number: number, title: "Ligar para o pintor hoje" })
      call_tool(token, "add_task_comment", { number: number, text: "Ele atende só de manhã" })
      _, moved = call_tool(token, "move_task", { number: number, column: "concluído" })
      expect(moved["moved"]).to include("column" => "Concluído", "title" => "Ligar para o pintor hoje")
      expect(task.reload.completed_at).to be_present
      expect(task.comments.first).to have_attributes(body: "Ele atende só de manhã", user: user)
      expect(task.events.map(&:kind)).to eq(%w[created moved])

      error, text = call_tool(token, "move_task", { number: number, column: "Inexistente" })
      expect(error).to be(true)
      expect(text).to include("A fazer", "QA") # diz as colunas válidas
      error, = call_tool(token, "update_task", { number: 999, title: "x" })
      expect(error).to be(true)
    end

    it "lets an authorized assistant create boards and create, change and reorder columns" do
      token = tokens_with(true)["access_token"]

      _, made = call_tool(token, "create_board", { name: "Casa", columns: %w[Ideias Fazendo Feito] })
      expect(made["created"]["columns"].map { |c| [c["name"], c["done"]] }).to eq([["Ideias", false], ["Fazendo", false], ["Feito", true]])
      expect(call_tool(token, "create_board", { name: "casa" }).first).to be(true) # nome repetido

      call_tool(token, "add_column", { board: "Casa", name: "Aguardando", color: "rose" })
      call_tool(token, "update_column", { board: "Casa", column: "Ideias", name: "Entrada", color: "violet" })
      _, moved = call_tool(token, "move_column", { board: "Casa", column: "Aguardando", position: 2 })
      expect(moved["board"]["columns"].map { |c| c["name"] }).to eq(%w[Entrada Aguardando Fazendo Feito])
      casa = account.task_boards.find_by!(name: "Casa")
      expect(casa.columns.find_by!(name: "Entrada").color).to eq("violet")

      call_tool(token, "rename_board", { board: "Casa", name: "Casa e reforma" })
      expect(casa.reload.name).to eq("Casa e reforma")

      # mover tarefa para frente e para trás, com comentário
      _, created = call_tool(token, "create_task", { title: "Pintar a sala", board: "Casa e reforma" })
      number = created["created"]["number"]
      call_tool(token, "move_task", { number: number, column: "Fazendo" })
      call_tool(token, "move_task", { number: number, column: "Entrada" })
      call_tool(token, "add_task_comment", { number: number, text: "Voltou: falta comprar a tinta" })
      task = account.tasks.find_by!(number: number)
      expect(task.events.map { |e| [e.from_column, e.to_column] }).to eq([[nil, "Entrada"], ["Entrada", "Fazendo"], ["Fazendo", "Entrada"]])

      error, text = call_tool(token, "update_column", { board: "Casa e reforma", column: "Feito", color: "laranja" })
      expect(error).to be(true)
      expect(text).to include("slate")
      expect(call_tool(token, "move_column", { board: "Casa e reforma", column: "Feito", position: 9 }).first).to be(true)
    end

    it "marks manual habits and logs weight, but refuses automatic habits" do
      token = tokens_with(true)["access_token"]
      category = create(:habit_category, account: account)
      manual = create(:habit, account: account, habit_category: category, name: "Ler 20 min")
      create(:habit, :auto_screen_time, account: account, habit_category: category, name: "Tela")

      _, done = call_tool(token, "set_habit_done", { habit: "ler 20 min" })
      expect(done).to include("done" => true)
      expect(manual.habit_checks.where(date: Date.current)).to exist
      call_tool(token, "set_habit_done", { habit: "Ler 20 min", done: false })
      expect(manual.habit_checks.where(date: Date.current)).not_to exist

      error, text = call_tool(token, "set_habit_done", { habit: "Tela" })
      expect(error).to be(true)
      expect(text).to include("automático")

      _, weight = call_tool(token, "log_weight", { kg: 81.4 })
      expect(weight).to include("weight_kg" => 81.4)
      expect(account.weight_entries.find_by(date: Date.current).weight_kg).to eq(81.4)
    end

    it "can be switched on and off later from the setup page, per assistant" do
      token = tokens_with(false)["access_token"]
      grant = OauthGrant.last
      patch oauth_grant_path(grant), params: { allow_write: "1" }
      expect(grant.reload).to be_write
      expect(call_tool(token, "create_task", { title: "Agora pode" }).first).to be(false)

      get setup_path
      expect(response.body).to include(I18n.t("setup.mcp.access_write"))
      patch oauth_grant_path(grant), params: { allow_write: "0" }
      expect(rpc(token, "tools/call", { name: "create_task", arguments: { title: "Não pode mais" } })["error"]["code"]).to eq(-32_602)
    end

    it "keeps the manual token read-only" do
      account.enable_mcp!
      names = rpc(account.mcp_token, "tools/list")["result"]["tools"].map { |t| t["name"] }
      expect(names).not_to include("create_task")
    end
  end

  it "rejects a wrong PKCE verifier and burns the code" do
    sign_in user
    client_id = register["client_id"]
    post oauth_authorize_path, params: authorize_params(client_id, decision: "approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri, code_verifier: "errado" * 10 }
    expect(JSON.parse(response.body)["error"]).to eq("invalid_grant")
    post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri, code_verifier: verifier }
    expect(response).to have_http_status(:bad_request)
  end

  it "expires access tokens and returns the denial to the client" do
    sign_in user
    client_id = register["client_id"]
    tokens = obtain_tokens(client_id)
    travel_to(2.hours.from_now) { expect(mcp_ping(tokens["access_token"])).to eq(401) }

    post oauth_authorize_path, params: authorize_params(client_id, decision: "deny")
    expect(Rack::Utils.parse_query(URI.parse(response.location).query)).to include("error" => "access_denied", "state" => "xyz")
  end

  it "never redirects to an unregistered address, and requires PKCE S256" do
    sign_in user
    client_id = register["client_id"]

    get oauth_authorize_path, params: authorize_params(client_id, redirect_uri: "https://evil.example/cb")
    expect(response).to have_http_status(:bad_request)
    expect(response.body).to include(I18n.t("oauth.invalid.bad_redirect"))

    get oauth_authorize_path, params: authorize_params("desconhecido")
    expect(response).to have_http_status(:bad_request)

    get oauth_authorize_path, params: authorize_params(client_id, code_challenge_method: "plain")
    expect(Rack::Utils.parse_query(URI.parse(response.location).query)["error"]).to eq("invalid_request")
  end

  it "allows any port for loopback redirects registered by desktop clients" do
    client = OauthClient.create!(client_id: "desk", redirect_uris: ["http://localhost:1234/callback"])
    expect(client.redirect_uri_allowed?("http://localhost:55123/callback")).to be(true)
    expect(client.redirect_uri_allowed?("http://localhost:55123/other")).to be(false)
    expect(client.redirect_uri_allowed?("http://evil.example:1234/callback")).to be(false)
  end

  describe Oauth::ClientResolver do
    let(:url) { "https://claude.ai/oauth/client-metadata.json" }

    def stub_fetch(resolver_class, body, address: "160.79.104.10")
      allow(Resolv).to receive(:getaddresses).and_return([address])
      http = instance_double(Net::HTTP, :ipaddr= => nil, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
      ok = Net::HTTPOK.new("1.1", "200", "OK")
      allow(ok).to receive(:body).and_return(body.to_json)
      allow(http).to receive(:request_get).and_return(ok)
      allow(Net::HTTP).to receive(:new).and_return(http)
      resolver_class.call(url)
    end

    it "creates a client from a published metadata document" do
      client = stub_fetch(described_class, { client_id: url, client_name: "Claude", redirect_uris: ["https://claude.ai/api/mcp/auth_callback"] })
      expect(client).to have_attributes(kind: "cimd", name: "Claude", client_id: url)
    end

    it "falls back to the next address when the first one is unreachable (IPv6 without a route)" do
      allow(Resolv).to receive(:getaddresses).and_return(["2607:6bc0::10", "160.79.104.10"])
      ok = Net::HTTPOK.new("1.1", "200", "OK")
      allow(ok).to receive(:body).and_return({ client_id: url, client_name: "Claude", redirect_uris: ["https://claude.ai/api/mcp/auth_callback"] }.to_json)
      tried = []
      allow(Net::HTTP).to receive(:new) do
        http = instance_double(Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
        allow(http).to receive(:ipaddr=) { |address| tried << address }
        allow(http).to receive(:request_get) { tried.last.include?(":") ? raise(Errno::ENETUNREACH) : ok }
        http
      end

      expect(described_class.call(url)).to have_attributes(name: "Claude")
      expect(tried.first).to eq("160.79.104.10") # IPv4 primeiro
    end

    it "refuses documents that claim another id and hosts that resolve to internal addresses" do
      expect(stub_fetch(described_class, { client_id: "https://outro.example/x", redirect_uris: ["https://a.example/cb"] })).to be_nil
      expect(Net::HTTP).not_to receive(:new)
      expect(stub_fetch(described_class, { client_id: url, redirect_uris: ["https://a.example/cb"] }, address: "10.0.0.5")).to be_nil
    end
  end
end
