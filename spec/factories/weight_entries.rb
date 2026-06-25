FactoryBot.define do
  factory :weight_entry do
    association :account
    date { Date.current }
    weight_kg { 80.0 }
  end
end
