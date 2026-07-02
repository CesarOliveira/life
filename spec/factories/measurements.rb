# == Schema Information
#
# Table name: measurements
#
#  id          :bigint           not null, primary key
#  category    :string           default("health"), not null
#  key         :string           not null
#  measured_on :date             not null
#  ref_high    :decimal(12, 3)
#  ref_low     :decimal(12, 3)
#  source      :string           default("manual"), not null
#  unit        :string
#  value       :decimal(12, 3)   not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  idx_measurements_unique                        (account_id,key,measured_on) UNIQUE
#  index_measurements_on_account_id               (account_id)
#  index_measurements_on_account_id_and_category  (account_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
