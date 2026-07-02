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
FactoryBot.define do
  factory :habit_check do
    association :habit
    date { Date.current }
  end
end
