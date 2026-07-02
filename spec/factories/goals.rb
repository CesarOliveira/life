# == Schema Information
#
# Table name: goals
#
#  id           :bigint           not null, primary key
#  achieved_on  :date
#  deadline     :date
#  metric_key   :string           not null
#  name         :string           not null
#  start_value  :decimal(12, 3)
#  target_value :decimal(12, 3)   not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_goals_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
