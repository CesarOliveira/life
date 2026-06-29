require "rails_helper"

RSpec.describe "Insights", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "renders the insights page" do
    get insights_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("insights.title"))
  end

  it "accepts a metric param" do
    get insights_path(metric: "steps")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("habits.auto_metrics.steps"))
  end

  it "renders the analysis when there is enough data" do
    habit = create(:habit, account: account, weekdays: (0..6).to_a)
    today = Date.current
    [0, 1, 2].each do |i|
      create(:measurement, account: account, key: "steps", value: 12_000, measured_on: today - i, category: "health")
      create(:habit_check, habit: habit, date: today - i)
    end
    [3, 4, 5].each do |i|
      create(:measurement, account: account, key: "steps", value: 3_000, measured_on: today - i, category: "health")
    end
    get insights_path(metric: "steps")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("insights.days_analyzed"))
  end
end
