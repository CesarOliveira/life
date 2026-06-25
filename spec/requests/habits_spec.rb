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
