require "rails_helper"

RSpec.describe HabitStats do
  let(:account) { create(:account) }

  def daily_habit
    create(:habit, account: account, weekdays: (0..6).to_a)
  end

  describe "#current_streak" do
    it "counts consecutive done days ending today" do
      habit = daily_habit
      today = Date.new(2026, 6, 24)
      [today, today - 1, today - 2].each { |d| create(:habit_check, habit: habit, date: d) }
      expect(HabitStats.new(habit, today: today).current_streak).to eq(3)
    end

    it "does not break when today is not done yet" do
      habit = daily_habit
      today = Date.new(2026, 6, 24)
      [today - 1, today - 2].each { |d| create(:habit_check, habit: habit, date: d) }
      expect(HabitStats.new(habit, today: today).current_streak).to eq(2)
    end

    it "is zero when yesterday was missed" do
      habit = daily_habit
      today = Date.new(2026, 6, 24)
      create(:habit_check, habit: habit, date: today - 2)
      expect(HabitStats.new(habit, today: today).current_streak).to eq(0)
    end
  end

  describe "#adherence" do
    it "is the percentage of scheduled days done in the window" do
      habit = daily_habit
      today = Date.new(2026, 6, 24)
      habit.update_column(:created_at, (today - 6).to_time)
      [today, today - 1, today - 3, today - 5].each { |d| create(:habit_check, habit: habit, date: d) }
      # 7 dias agendados, 4 feitos => 57%
      expect(HabitStats.new(habit, today: today).adherence(days: 7)).to eq(57)
    end
  end
end
