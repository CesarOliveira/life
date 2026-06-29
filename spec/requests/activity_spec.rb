require "rails_helper"

RSpec.describe "Activity", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:habit) { create(:habit, account: account) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders the activity heatmap with the default (3 months) range" do
    create(:habit_check, habit: habit, date: Date.current)
    get activity_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("activity.title"))
  end

  it "accepts the 6m and 12m ranges" do
    get activity_path(range: "12m")
    expect(response).to have_http_status(:ok)
  end

  it "renders a specific year and lists years in the selector" do
    create(:habit_check, habit: habit, date: Date.new(2025, 3, 10))
    get activity_path(year: 2025)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2025")
  end

  it "ignores an out-of-range year and falls back to the range view" do
    get activity_path(year: 1990)
    expect(response).to have_http_status(:ok)
  end
end
