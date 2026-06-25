# == Schema Information
#
# Table name: accounts
#
#  id                   :bigint           not null, primary key
#  join_code            :string
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  owner_id             :bigint
#
# Indexes
#
#  index_accounts_on_join_code  (join_code) UNIQUE
#  index_accounts_on_owner_id   (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Conta #{n}" }
    association :owner, factory: :user
    # join_code é gerado por callback (before_create)
  end
end
