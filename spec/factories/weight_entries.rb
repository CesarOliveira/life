# == Schema Information
#
# Table name: weight_entries
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  weight_kg  :decimal(5, 2)    not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_weight_entries_on_account_id           (account_id)
#  index_weight_entries_on_account_id_and_date  (account_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :weight_entry do
    association :account
    date { Date.current }
    weight_kg { 80.0 }
  end
end
