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

  describe "weekly_count habits" do
    let(:today) { Date.new(2026, 6, 24) } # quarta; semana dom..sáb = 21..27

    def weekly_habit(target: 3)
      habit = create(:habit, :weekly_count, account: account, weekly_target: target)
      habit.update_column(:created_at, (today - 60).to_time)
      habit
    end

    it "counts checks done in the current week" do
      habit = weekly_habit
      [Date.new(2026, 6, 22), Date.new(2026, 6, 24)].each { |d| create(:habit_check, habit: habit, date: d) }
      stats = HabitStats.new(habit, today: today)
      expect(stats.done_this_week).to eq(2)
      expect(stats.week_met?).to be(false)
    end

    it "marks the week as met when the target is reached" do
      habit = weekly_habit(target: 2)
      [Date.new(2026, 6, 22), Date.new(2026, 6, 24)].each { |d| create(:habit_check, habit: habit, date: d) }
      expect(HabitStats.new(habit, today: today).week_met?).to be(true)
    end

    it "counts consecutive weeks hitting the target as the streak" do
      habit = weekly_habit(target: 2)
      [Date.new(2026, 6, 22), Date.new(2026, 6, 24)].each { |d| create(:habit_check, habit: habit, date: d) } # semana atual: 2
      [Date.new(2026, 6, 15), Date.new(2026, 6, 17)].each { |d| create(:habit_check, habit: habit, date: d) } # semana -1: 2
      create(:habit_check, habit: habit, date: Date.new(2026, 6, 10)) # semana -2: 1 => quebra
      expect(HabitStats.new(habit, today: today).current_streak).to eq(2)
    end

    it "does not break the streak while the current week is in progress" do
      habit = weekly_habit(target: 3)
      create(:habit_check, habit: habit, date: Date.new(2026, 6, 22)) # atual incompleta (1/3)
      [Date.new(2026, 6, 15), Date.new(2026, 6, 16), Date.new(2026, 6, 17)].each { |d| create(:habit_check, habit: habit, date: d) } # -1 completa
      expect(HabitStats.new(habit, today: today).current_streak).to eq(1)
    end
  end

  describe "#strength" do
    let(:today) { Date.new(2026, 6, 24) }

    def aged_daily_habit
      habit = create(:habit, account: account, weekdays: (0..6).to_a)
      habit.update_column(:created_at, (today - 60).to_time)
      habit
    end

    it "is :new when the habit has little history" do
      habit = create(:habit, account: account, weekdays: (0..6).to_a)
      habit.update_column(:created_at, (today - 2).to_time)
      expect(HabitStats.new(habit, today: today).strength).to eq(:new)
    end

    it "is :strong with high adherence" do
      habit = aged_daily_habit
      (0..27).each { |i| create(:habit_check, habit: habit, date: today - i) }
      expect(HabitStats.new(habit, today: today).strength).to eq(:strong)
    end

    it "is :medium with mid adherence" do
      habit = aged_daily_habit
      (0..15).each { |i| create(:habit_check, habit: habit, date: today - i) } # 16/28 = 57%
      expect(HabitStats.new(habit, today: today).strength).to eq(:medium)
    end

    it "is :weak with low adherence" do
      habit = aged_daily_habit
      [today, today - 5, today - 10].each { |d| create(:habit_check, habit: habit, date: d) } # 3/28
      expect(HabitStats.new(habit, today: today).strength).to eq(:weak)
    end
  end
end
