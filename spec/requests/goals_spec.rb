require "rails_helper"

RSpec.describe "Goals", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  describe "GET /goals" do
    it "lists goals with progress" do
      create(:goal, account: account, name: "Chegar a 80kg", metric_key: "weight", start_value: 90, target_value: 80)
      create(:weight_entry, account: account, weight_kg: 85)
      get goals_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Chegar a 80kg")
    end
  end

  describe "POST /goals" do
    it "creates a goal and auto-fills the start value from current data" do
      create(:weight_entry, account: account, weight_kg: 92)
      expect {
        post goals_path, params: { goal: { name: "Meta peso", metric_key: "weight", target_value: "80" } }
      }.to change(account.goals, :count).by(1)

      goal = account.goals.last
      expect(goal.start_value).to eq(92)
    end

    it "re-renders on invalid input" do
      post goals_path, params: { goal: { name: "", metric_key: "weight", target_value: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /goals/:id" do
    it "removes the goal" do
      goal = create(:goal, account: account)
      expect { delete goal_path(goal) }.to change(account.goals, :count).by(-1)
    end

    it "does not remove another account's goal" do
      other = create(:goal)
      delete goal_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end
