FactoryBot.define do
  factory :measurement do
    association :account
    key { "steps" }
    value { 8000 }
    unit { "passos" }
    measured_on { Date.current }
    category { "health" }
    source { "manual" }

    trait :exam do
      key { "glucose" }
      value { 95 }
      unit { "mg/dL" }
      category { "exam" }
      ref_low { 70 }
      ref_high { 99 }
    end
  end
end
