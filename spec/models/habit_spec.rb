# == Schema Information
#
# Table name: habits
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  app_bundle_ids  :string           default([]), not null, is an Array
#  auto            :boolean          default(FALSE), not null
#  color           :string           default("#6366f1"), not null
#  comparator      :string
#  description     :text
#  frequency       :string           default("weekly_days"), not null
#  metric_key      :string
#  name            :string           not null
#  position        :integer          default(0), not null
#  threshold_value :decimal(12, 3)
#  weekdays        :integer          default([0, 1, 2, 3, 4, 5, 6]), not null, is an Array
#  weekly_target   :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
# Indexes
#
#  index_habits_on_account_id             (account_id)
#  index_habits_on_account_id_and_active  (account_id,active)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require "rails_helper"

RSpec.describe Habit, type: :model do
  it { is_expected.to belong_to(:account) }
  it { is_expected.to have_many(:habit_checks).dependent(:destroy) }

  it "is invalid without a name" do
    expect(build(:habit, name: nil)).not_to be_valid
  end

  it "requires at least one weekday" do
    expect(build(:habit, weekdays: [])).not_to be_valid
  end

  it "rejects invalid weekday numbers" do
    expect(build(:habit, weekdays: [9])).not_to be_valid
  end

  describe "frequency" do
    it "rejects an unknown frequency" do
      expect(build(:habit, frequency: "monthly")).not_to be_valid
    end

    it "requires a weekly_target for weekly_count" do
      expect(build(:habit, :weekly_count, weekly_target: nil)).not_to be_valid
      expect(build(:habit, :weekly_count, weekly_target: 0)).not_to be_valid
      expect(build(:habit, :weekly_count, weekly_target: 8)).not_to be_valid
      expect(build(:habit, :weekly_count, weekly_target: 3)).to be_valid
    end

    it "does not require weekdays for weekly_count" do
      expect(build(:habit, :weekly_count, weekdays: [])).to be_valid
    end

    it "is scheduled on any day when weekly_count" do
      habit = build(:habit, :weekly_count)
      expect(habit.scheduled_on?(Date.new(2026, 6, 22))).to be(true)
      expect(habit.scheduled_on?(Date.new(2026, 6, 23))).to be(true)
    end
  end

  describe "automatic habits" do
    it "requires metric_key, comparator and threshold when auto" do
      expect(build(:habit, auto: true, metric_key: nil, comparator: "lte", threshold_value: 3)).not_to be_valid
      expect(build(:habit, auto: true, metric_key: "screen_time_total", comparator: "bad", threshold_value: 3)).not_to be_valid
      expect(build(:habit, auto: true, metric_key: "screen_time_total", comparator: "lte", threshold_value: nil)).not_to be_valid
      expect(build(:habit, auto: true, metric_key: "screen_time_total", comparator: "lte", threshold_value: 3)).to be_valid
    end

    it "is scheduled every day" do
      habit = build(:habit, :auto_screen_time)
      expect(habit.scheduled_on?(Date.new(2026, 6, 22))).to be(true)
      expect(habit.scheduled_on?(Date.new(2026, 6, 23))).to be(true)
    end
  end

  describe "#effective_weekly_target" do
    it "is the weekly_target for weekly_count" do
      expect(build(:habit, :weekly_count, weekly_target: 4).effective_weekly_target).to eq(4)
    end

    it "is the number of scheduled weekdays for weekly_days" do
      expect(build(:habit, weekdays: [1, 3, 5]).effective_weekly_target).to eq(3)
    end
  end

  describe "#daily?" do
    it "is true when every weekday is set" do
      expect(build(:habit, weekdays: (0..6).to_a)).to be_daily
    end

    it "is false for a subset" do
      expect(build(:habit, weekdays: [1, 3, 5])).not_to be_daily
    end
  end

  describe "#scheduled_on?" do
    it "matches the weekday of the date" do
      monday = Date.new(2026, 6, 22) # segunda-feira (wday 1)
      habit = build(:habit, weekdays: [1])
      expect(habit.scheduled_on?(monday)).to be(true)
      expect(habit.scheduled_on?(monday + 1)).to be(false)
    end
  end

  describe "#checked_on?" do
    it "is true when a check exists for the date" do
      habit = create(:habit)
      create(:habit_check, habit: habit, date: Date.current)
      expect(habit.checked_on?(Date.current)).to be(true)
      expect(habit.checked_on?(Date.current - 1)).to be(false)
    end
  end
end
