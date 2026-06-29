FactoryBot.define do
  factory :habit do
    association :account
    sequence(:name) { |n| "Hábito #{n}" }
    color { Habit::DEFAULT_COLOR }
    frequency { "weekly_days" }
    weekdays { Habit::WEEKDAYS }
    active { true }

    trait :weekly_count do
      frequency { "weekly_count" }
      weekly_target { 3 }
    end

    trait :auto_screen_time do
      auto { true }
      metric_key { "screen_time_total" }
      comparator { "lte" }
      threshold_value { 3 }
    end
  end
end
