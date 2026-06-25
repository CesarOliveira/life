require "rails_helper"

RSpec.describe "Screen time", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders, shows per-app usage and exposes a token" do
    create(:app_usage, account: account, name: "Instagram", seconds: 7200)
    get screen_time_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Instagram")
    expect(account.reload.api_token).to be_present
  end

  it "regenerates the token" do
    old = account.api_token
    post regenerate_screen_time_token_path
    expect(account.reload.api_token).not_to eq(old)
    expect(response).to redirect_to(screen_time_path)
  end
end
