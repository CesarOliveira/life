# Um resultado de exame do usuário: valor, unidade e a faixa de referência
# COMO VEIO DO LAUDO (ou digitada) — pode não existir. O catálogo (ExamType)
# só dá nome/descrição/grupo; o Life não fornece referência médica.
# == Schema Information
#
# Table name: exam_results
#
#  id           :bigint           not null, primary key
#  measured_on  :date             not null
#  ref_high     :decimal(12, 3)
#  ref_low      :decimal(12, 3)
#  source       :string           default("manual"), not null
#  unit         :string
#  value        :decimal(12, 3)   not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  exam_type_id :bigint           not null
#
# Indexes
#
#  idx_exam_results_unique             (account_id,exam_type_id,measured_on) UNIQUE
#  index_exam_results_on_account_id    (account_id)
#  index_exam_results_on_exam_type_id  (exam_type_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (exam_type_id => exam_types.id)
#
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
