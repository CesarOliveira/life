# Registro de cada extração de exame (import de PDF): tamanho do arquivo,
# modelos usados, tokens e custo (USD) — visível no /admin para acompanhar
# o gasto com a API.
# == Schema Information
#
# Table name: exam_extractions
#
#  id            :bigint           not null, primary key
#  cost_usd      :decimal(10, 6)   default(0.0), not null
#  duration_ms   :integer          default(0), not null
#  error         :string
#  file_bytes    :integer          default(0), not null
#  input_tokens  :integer          default(0), not null
#  models_used   :string           default(""), not null
#  output_tokens :integer          default(0), not null
#  rows_count    :integer          default(0), not null
#  status        :string           default("success"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_exam_extractions_on_account_id  (account_id)
#  index_exam_extractions_on_created_at  (created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ExamExtraction < ApplicationRecord
  belongs_to :account

  STATUSES = %w[success failed].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def success?
    status == "success"
  end

  # Custo formatado: "$0.0031".
  def cost_label
    format("$%.4f", cost_usd)
  end
end
