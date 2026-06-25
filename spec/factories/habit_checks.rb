FactoryBot.define do
  factory :habit_check do
    association :habit
    date { Date.current }
  end
end
