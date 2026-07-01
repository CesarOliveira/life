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

  it "regenerates the token and returns to the caller (fallback: setup)" do
    old = account.api_token
    post regenerate_screen_time_token_path
    expect(account.reload.api_token).not_to eq(old)
    expect(response).to redirect_to(setup_path)
  end

  it "masks the token on the page but serves the full token on demand" do
    account.update!(api_token: "abcd1234567890efgh")
    get screen_time_path
    expect(response.body).not_to include("abcd1234567890efgh")

    get screen_time_token_path
    expect(response.body.strip).to eq("abcd1234567890efgh")
  end

  it "shows a per-app daily chart" do
    create(:app_usage, account: account, bundle_id: "Instagram", name: "Instagram", date: Date.current, seconds: 3600)
    create(:app_usage, account: account, bundle_id: "Instagram", name: "Instagram", date: Date.current - 1, seconds: 1800)
    get screen_time_app_path(bundle_id: "Instagram")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Instagram")
  end
end
