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

      after(:build) do |_goal|
        ExamType.find_by(key: "vitamin_d") ||
          create(:exam_type, key: "vitamin_d", name_pt: "Vitamina D (25-OH)", name_en: "Vitamin D (25-OH)")
      end
    end
  end
end
