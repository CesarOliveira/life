FactoryBot.define do
  factory :habit_category do
    association :account
    sequence(:name) { |n| "Categoria #{n}" }
    position { 0 }
  end
end
