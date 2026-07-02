# Registro de cada extração de exame (import de PDF): tamanho do arquivo,
# modelos usados, tokens e custo (USD) — visível no /admin para acompanhar
# o gasto com a API.
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
