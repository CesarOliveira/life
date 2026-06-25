FactoryBot.define do
  factory :app_usage do
    association :account
    device { "iphone" }
    date { Date.current }
    sequence(:bundle_id) { |n| "com.example.app#{n}" }
    name { "App" }
    seconds { 600 }
  end
end
