# == Schema Information
#
# Table name: habit_categories
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_habit_categories_on_account_id           (account_id)
#  index_habit_categories_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :habit_category do
    association :account
    sequence(:name) { |n| "Categoria #{n}" }
    position { 0 }
  end
end
