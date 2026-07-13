require "rails_helper"

RSpec.describe "Shortcuts", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "serves the signed .shortcut file for download" do
    get health_shortcut_path
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("application/octet-stream")
    expect(response.headers["Content-Disposition"]).to include("Tempo-Tela-Life.shortcut")
    expect(response.body.bytesize).to be > 0
  end

  it "é público (funciona sem login — abre no Safari, que não tem a sessão)" do
    sign_out user
    get health_shortcut_path
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("application/octet-stream")
  end
end
