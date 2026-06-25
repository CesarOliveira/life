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
