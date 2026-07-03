require "rails_helper"

RSpec.describe "Activity", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:habit) { create(:habit, account: account) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders the current year grid with the year sidebar and radar overview" do
    create(:habit_check, habit: habit, date: Date.current)
    get activity_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("activity.overview"))
    expect(response.body).to include(Date.current.year.to_s)
    expect(response.body).to include("radar-chart")
  end

  it "renders a specific year and lists all years with activity" do
    create(:habit_check, habit: habit, date: Date.new(2025, 3, 10))
    get activity_path(year: 2025)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2025")
    expect(response.body).to include(Date.current.year.to_s) # lateral
  end

  it "falls back to the current year for an unknown year param" do
    get activity_path(year: 1999)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("activity.period_year", year: Date.current.year))
  end
end
