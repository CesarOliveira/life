# Um resultado de exame do usuário: valor, unidade e a faixa de referência
# COMO VEIO DO LAUDO (ou digitada) — pode não existir. O catálogo (ExamType)
# só dá nome/descrição/grupo; o Life não fornece referência médica.
class ExamResult < ApplicationRecord
  belongs_to :account
  belongs_to :exam_type

  SOURCES = %w[manual pdf api].freeze

  validates :value, presence: true, numericality: true
  validates :measured_on, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :exam_type_id, uniqueness: { scope: [:account_id, :measured_on] }

  scope :chronological, -> { order(:measured_on) }
  scope :recent_first, -> { order(measured_on: :desc) }

  delegate :name, :description, to: :exam_type, prefix: false, allow_nil: false

  def label
    exam_type.name
  end

  def out_of_range?
    return false if value.nil?

    (ref_low.present? && value < ref_low) || (ref_high.present? && value > ref_high)
  end

  def reference?
    ref_low.present? || ref_high.present?
  end

  # Valor sem zeros à direita (8.0 -> 8).
  def display_value
    value == value.to_i ? value.to_i : value
  end
end
