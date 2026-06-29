require "rails_helper"

RSpec.describe HabitRuleEvaluator do
  let(:account) { create(:account) }
  let(:today) { Date.new(2026, 6, 24) }

  describe "screen time (≤) auto habit" do
    let!(:habit) { create(:habit, :auto_screen_time, account: account, threshold_value: 3) } # tela ≤ 3h

    it "creates a check when usage is under the threshold" do
      create(:app_usage, account: account, date: today, seconds: 2 * 3600) # 2h
      expect { described_class.new(account).evaluate([today]) }
        .to change { habit.habit_checks.where(date: today).count }.from(0).to(1)
    end

    it "removes the check when usage exceeds the threshold" do
      create(:habit_check, habit: habit, date: today)
      create(:app_usage, account: account, date: today, seconds: 5 * 3600) # 5h
      expect { described_class.new(account).evaluate([today]) }
        .to change { habit.habit_checks.where(date: today).count }.from(1).to(0)
    end

    it "leaves the check untouched when there is no data" do
      create(:habit_check, habit: habit, date: today)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).to exist
    end
  end

  describe "sleep (≥) auto habit" do
    let!(:habit) { create(:habit, account: account, auto: true, metric_key: "sleep_hours", comparator: "gte", threshold_value: 7) }

    it "creates a check when sleep meets the goal" do
      create(:measurement, account: account, key: "sleep_minutes", value: (7 * 60) + 30, measured_on: today, category: "health")
      expect { described_class.new(account).evaluate([today]) }
        .to change { habit.habit_checks.where(date: today).count }.by(1)
    end

    it "does not create a check when sleep is short" do
      create(:measurement, account: account, key: "sleep_minutes", value: 6 * 60, measured_on: today, category: "health")
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).not_to exist
    end
  end

  describe "#backfill" do
    let(:habit) { create(:habit, :auto_screen_time, account: account, threshold_value: 3) }

    it "evaluates each day in the window" do
      create(:app_usage, account: account, date: today, seconds: 1 * 3600)
      create(:app_usage, account: account, date: today - 1, seconds: 9 * 3600)
      described_class.new(account).backfill(habit, from: today - 2, to: today)
      expect(habit.habit_checks.where(date: today)).to exist
      expect(habit.habit_checks.where(date: today - 1)).not_to exist
    end
  end
end
