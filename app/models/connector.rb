# Integração externa que puxa dados automaticamente (filosofia do app: nada de
# marcar na mão). Cada conector alimenta Measurements diários; hábitos
# automáticos, metas e insights funcionam em cima sem código extra.
# == Schema Information
#
# Table name: connectors
#
#  id             :bigint           not null, primary key
#  access_token   :text
#  kind           :string           not null
#  last_error     :string
#  last_points    :integer          default(0), not null
#  last_synced_at :datetime
#  settings       :jsonb            not null
#  status         :string           default("active"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_connectors_on_account_id           (account_id)
#  index_connectors_on_account_id_and_kind  (account_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Connector < ApplicationRecord
  KINDS = %w[github].freeze
  STATUSES = %w[active paused error].freeze

  belongs_to :account

  encrypts :access_token

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def login
    settings["login"]
  end

  def backfill_years
    (settings["backfill_years"] || 5).to_i
  end

  def mark_synced!(points)
    update!(status: "active", last_synced_at: Time.current, last_error: nil, last_points: points)
  end

  def mark_error!(message)
    update!(status: "error", last_error: message.to_s.first(255))
  end
end
