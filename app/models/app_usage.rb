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
class AppUsage < ApplicationRecord
  belongs_to :account

  validates :device, presence: true
  validates :date, presence: true
  validates :bundle_id, presence: true
  validates :seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bundle_id, uniqueness: { scope: [:account_id, :device, :date] }

  scope :in_range, ->(range) { where(date: range) }
end
