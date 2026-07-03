require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:habit) { create(:habit, account: account) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders the merged dashboard: stats, year grid, today's habits and radar" do
    create(:habit_check, habit: habit, date: Date.current)
    get authenticated_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("dashboard.habits_today"))
    expect(response.body).to include(I18n.t("activity.overview"))
    expect(response.body).to include("radar-chart")
    expect(response.body).to include(Date.current.year.to_s)
  end

  it "accepts a year param and falls back to the current year when unknown" do
    create(:habit_check, habit: habit, date: Date.new(2025, 3, 10))
    get authenticated_root_path(year: 2025)
    expect(response.body).to include(I18n.t("activity.period_year", year: 2025))

    get authenticated_root_path(year: 1999)
    expect(response.body).to include(I18n.t("activity.period_year", year: Date.current.year))
  end

  it "redirects the legacy /activity path to the dashboard keeping the year" do
    get "/activity", params: { year: 2025 }
    expect(response).to redirect_to("/?year=2025")
  end
end
