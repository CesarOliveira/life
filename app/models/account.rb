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
class Account < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :habits, dependent: :destroy
  has_many :weight_entries, dependent: :destroy
  has_many :app_usages, dependent: :destroy
  has_many :measurements, dependent: :destroy
  has_many :goals, dependent: :destroy

  # Token pessoal para a API de ingestão (ex.: script do Mac enviando uso por app).
  has_secure_token :api_token

  validates :name, presence: true
  validates :join_code, uniqueness: true, allow_nil: true

  before_create :ensure_join_code

  def admin_memberships
    memberships.where(role: %w[owner admin], status: "active")
  end

  def pending_memberships
    memberships.where(status: "pending")
  end

  private

  def ensure_join_code
    return if join_code.present?

    loop do
      self.join_code = SecureRandom.hex(5)
      break unless Account.exists?(join_code: join_code)
    end
  end
end
