# == Schema Information
#
# Table name: habit_checks
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  habit_id   :bigint           not null
#
# Indexes
#
#  index_habit_checks_on_habit_id           (habit_id)
#  index_habit_checks_on_habit_id_and_date  (habit_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (habit_id => habits.id)
#
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
