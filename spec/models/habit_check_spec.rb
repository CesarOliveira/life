require "rails_helper"

RSpec.describe HabitCheck, type: :model do
  it { is_expected.to belong_to(:habit) }

  it "requires a date" do
    expect(build(:habit_check, date: nil)).not_to be_valid
  end

  it "is unique per habit and date" do
    habit = create(:habit)
    create(:habit_check, habit: habit, date: Date.current)
    expect(build(:habit_check, habit: habit, date: Date.current)).not_to be_valid
  end
end
