FactoryBot.define do
  factory :exam_group do
    sequence(:key) { |n| "grupo_#{n}" }
    sequence(:name_pt) { |n| "Grupo #{n}" }
    sequence(:name_en) { |n| "Group #{n}" }
    position { 0 }
  end

  factory :exam_type do
    association :exam_group
    sequence(:key) { |n| "exame_#{n}" }
    sequence(:name_pt) { |n| "Exame #{n}" }
    sequence(:name_en) { |n| "Exam #{n}" }
    aliases { [] }
    position { 0 }
  end

  factory :exam_result do
    association :account
    association :exam_type
    value { 95 }
    unit { "mg/dL" }
    measured_on { Date.current }
    source { "manual" }
  end
end
