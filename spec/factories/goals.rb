FactoryBot.define do
  factory :goal do
    association :account
    sequence(:name) { |n| "Meta #{n}" }
    metric_key { "weight" }
    start_value { 90 }
    target_value { 80 }

    trait :exam do
      metric_key { "vitamin_d" }
      start_value { 20 }
      target_value { 40 }
    end
  end
end
