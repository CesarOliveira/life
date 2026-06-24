# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  role       :string           default("member"), not null
#  status     :string           default("pending"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_account_id              (account_id)
#  index_memberships_on_status                  (status)
#  index_memberships_on_user_id                 (user_id)
#  index_memberships_on_user_id_and_account_id  (user_id,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Membership < ApplicationRecord
  ROLES    = %w[owner admin member].freeze
  STATUSES = %w[pending active].freeze

  belongs_to :user
  belongs_to :account

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :account_id }

  scope :active,  -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }

  def admin?
    %w[owner admin].include?(role)
  end

  def owner?
    role == "owner"
  end

  def active?
    status == "active"
  end
end
