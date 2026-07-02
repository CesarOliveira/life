# == Schema Information
#
# Table name: app_usages
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  device     :string           default("iphone"), not null
#  name       :string
#  seconds    :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  bundle_id  :string           not null
#
# Indexes
#
#  idx_app_usages_unique           (account_id,device,date,bundle_id) UNIQUE
#  index_app_usages_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
