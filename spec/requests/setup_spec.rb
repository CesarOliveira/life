require "rails_helper"

RSpec.describe "Setup", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "shows the masked token and the Mac collection status" do
    account.update!(api_token: "abcd1234567890efgh")
    create(:app_usage, account: account, date: Date.current - 1, seconds: 600)
    get setup_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("abcd1234567890efgh") # token mascarado
    expect(response.body).to include(I18n.t("setup.mac.section"))
    expect(response.body).to include(I18n.t("setup.mac.never_received"))
    expect(response.body).to include("tempodetela-life")
    expect(response.body).not_to include(".shortcut")
  end

  it "requires authentication" do
    sign_out user
    get setup_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
