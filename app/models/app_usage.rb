class AppUsage < ApplicationRecord
  belongs_to :account

  validates :device, presence: true
  validates :date, presence: true
  validates :bundle_id, presence: true
  validates :seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bundle_id, uniqueness: { scope: [:account_id, :device, :date] }

  scope :in_range, ->(range) { where(date: range) }
end
