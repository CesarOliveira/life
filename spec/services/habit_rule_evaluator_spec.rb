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

  describe "bedtime (dormir antes de 00:30) auto habit" do
    # threshold_value = 30 (00:30); comparator lte com ciclo de meia-noite.
    let!(:habit) do
      create(:habit, account: account, auto: true, metric_key: "sleep_bedtime", comparator: "lte", threshold_value: 30)
    end

    def bedtime(minutes)
      create(:measurement, account: account, key: "sleep_bedtime", value: minutes, measured_on: today, category: "health")
    end

    it "marks done when bedtime is 23:30 (before 00:30, cruzando meia-noite)" do
      bedtime(23 * 60 + 30) # 1410
      expect { described_class.new(account).evaluate([today]) }
        .to change { habit.habit_checks.where(date: today).count }.from(0).to(1)
    end

    it "marks done when bedtime is 00:20" do
      bedtime(20)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).to exist
    end

    it "does not mark when bedtime is 01:00" do
      bedtime(60)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).not_to exist
    end
  end

  describe "social media (≤ 2h, apps escolhidos) auto habit" do
    let!(:habit) do
      create(:habit, account: account, auto: true, metric_key: "social_apps", comparator: "lte",
                     threshold_value: 2, app_bundle_ids: %w[Instagram Facebook])
    end

    it "marks done when chosen apps sum under the threshold" do
      create(:app_usage, account: account, bundle_id: "Instagram", date: today, seconds: 3600)
      create(:app_usage, account: account, bundle_id: "Facebook", date: today, seconds: 1800)
      expect { described_class.new(account).evaluate([today]) }
        .to change { habit.habit_checks.where(date: today).count }.from(0).to(1)
    end

    it "does not mark when chosen apps exceed the threshold" do
      create(:app_usage, account: account, bundle_id: "Instagram", date: today, seconds: 3 * 3600)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).not_to exist
    end

    it "marks done when there is usage but none of the chosen apps (0 <= max)" do
      create(:app_usage, account: account, bundle_id: "WhatsApp", date: today, seconds: 3600)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).to exist
    end

    it "skips when there is no usage data at all that day" do
      create(:habit_check, habit: habit, date: today)
      described_class.new(account).evaluate([today])
      expect(habit.habit_checks.where(date: today)).to exist # inalterado
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
