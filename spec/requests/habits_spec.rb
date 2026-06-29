require "rails_helper"

RSpec.describe "Habits", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  describe "GET /habits" do
    it "lists the current account's habits" do
      create(:habit, account: account, name: "Beber água")
      get habits_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Beber água")
    end

    it "does not show habits from other accounts" do
      create(:habit, name: "Hábito secreto de outra conta")
      get habits_path
      expect(response.body).not_to include("Hábito secreto de outra conta")
    end
  end

  describe "POST /habits" do
    it "creates a habit scoped to the current account" do
      expect {
        post habits_path, params: { habit: { name: "Ler", color: "#ff0000", weekdays: %w[1 3 5] } }
      }.to change(account.habits, :count).by(1)

      expect(response).to redirect_to(habits_path)
      expect(account.habits.last.weekdays).to eq([1, 3, 5])
    end

    it "re-renders with errors on invalid input" do
      post habits_path, params: { habit: { name: "", weekdays: [""] } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /habits/:id" do
    it "renders the habit page with its timeline" do
      habit = create(:habit, account: account, name: "Meditar")
      create(:habit_check, habit: habit, date: Date.current)
      get habit_path(habit)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Meditar")
    end

    it "does not expose another account's habit" do
      other = create(:habit, name: "Hábito alheio")
      get habit_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /habits with weekly_count" do
    it "creates a times-per-week habit" do
      post habits_path, params: { habit: { name: "Academia", color: "#00ff00", frequency: "weekly_count", weekly_target: "3" } }
      expect(response).to redirect_to(habits_path)
      habit = account.habits.last
      expect(habit.frequency).to eq("weekly_count")
      expect(habit.weekly_target).to eq(3)
    end
  end

  describe "POST /habits/:id/toggle" do
    let(:habit) { create(:habit, account: account) }

    it "creates a check when none exists" do
      expect {
        post toggle_habit_path(habit), params: { date: Date.current.iso8601 }
      }.to change(habit.habit_checks, :count).by(1)
    end

    it "removes the check when it already exists" do
      create(:habit_check, habit: habit, date: Date.current)
      expect {
        post toggle_habit_path(habit), params: { date: Date.current.iso8601 }
      }.to change(habit.habit_checks, :count).by(-1)
    end
  end

  context "when not signed in" do
    before { sign_out user }

    it "redirects to the login page" do
      get habits_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
