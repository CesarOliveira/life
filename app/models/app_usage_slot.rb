# == Schema Information
#
# Table name: app_usage_slots
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  device     :string           default("iphone"), not null
#  name       :string
#  seconds    :integer          default(0), not null
#  slot       :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  bundle_id  :string           not null
#
# Indexes
#
#  idx_app_usage_slots_unique                    (account_id,device,date,slot,bundle_id) UNIQUE
#  index_app_usage_slots_on_account_id           (account_id)
#  index_app_usage_slots_on_account_id_and_date  (account_id,date)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AppUsageSlot < ApplicationRecord
  SLOT_MINUTES = 15
  SLOTS_PER_DAY = 96

  belongs_to :account

  validates :slot, inclusion: { in: 0...SLOTS_PER_DAY }
  validates :seconds, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: SLOT_MINUTES * 60 }

  def self.label(slot)
    format("%02d:%02d", slot / 4, (slot % 4) * SLOT_MINUTES)
  end
end
