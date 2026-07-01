require "rails_helper"

RSpec.describe "Setup", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders a single-flow checklist with the masked token and download link" do
    account.update!(api_token: "abcd1234567890efgh")
    get setup_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(health_shortcut_path(v: HealthShortcutBuilder::VERSION))
    expect(response.body).not_to include("abcd1234567890efgh") # token mascarado
    expect(response.body).to include(I18n.t("setup.shortcut_section"))
  end

  it "requires authentication" do
    sign_out user
    get setup_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
