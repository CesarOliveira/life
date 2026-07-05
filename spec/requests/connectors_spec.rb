require "rails_helper"

RSpec.describe "Connectors", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
    allow(Connectors::Github).to receive(:configured?).and_return(true)
  end

  it "completes the OAuth flow: redirect -> callback creates the connector and enqueues backfill" do
    post github_connect_connectors_path
    expect(response.location).to start_with("https://github.com/login/oauth/authorize")
    state = Rack::Utils.parse_query(URI(response.location).query)["state"]

    allow(Connectors::Github).to receive_messages(exchange_code: "gho_tok", viewer_login: "cesar")
    expect {
      get github_callback_connectors_path, params: { code: "abc", state: state }
    }.to have_enqueued_job(ConnectorSyncJob).with(anything, full: true)

    connector = account.connectors.find_by(kind: "github")
    expect(connector.access_token).to eq("gho_tok")
    expect(connector.login).to eq("cesar")
    expect(response).to redirect_to(setup_path)
  end

  it "rejects a callback with wrong state" do
    get github_callback_connectors_path, params: { code: "abc", state: "forjado" }
    expect(account.connectors.count).to eq(0)
    expect(flash[:alert]).to eq(I18n.t("connectors.state_mismatch"))
  end

  it "enqueues a manual sync and disconnects" do
    connector = Connector.create!(account: account, kind: "github", access_token: "t")
    expect { post sync_connector_path(connector) }.to have_enqueued_job(ConnectorSyncJob)

    delete connector_path(connector)
    expect(account.connectors.count).to eq(0)
  end
end
