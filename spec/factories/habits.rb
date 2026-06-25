FactoryBot.define do
  factory :habit do
    association :account
    sequence(:name) { |n| "Hábito #{n}" }
    color { Habit::DEFAULT_COLOR }
    weekdays { Habit::WEEKDAYS }
    active { true }
  end
end
