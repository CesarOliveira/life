class Goal < ApplicationRecord
  belongs_to :account

  # Métricas alvo: peso (weight_entries) + métricas de saúde + tipos de exame.
  def self.metric_keys
    ["weight"] + Measurement::CATALOG.keys + ExamType.ordered.pluck(:key)
  end

  validates :name, presence: true
  validates :metric_key, presence: true, inclusion: { in: ->(_goal) { Goal.metric_keys } }
  validates :target_value, presence: true, numericality: true
  validates :start_value, numericality: true, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }

  # Tipo de exame quando a métrica é um exame (senão nil).
  def exam_type
    return nil if metric_key == "weight" || Measurement::CATALOG.key?(metric_key)

    @exam_type ||= ExamType.find_by(key: metric_key)
  end

  def unit
    return "kg" if metric_key == "weight"
    return Measurement.meta(metric_key)[:unit] if Measurement::CATALOG.key?(metric_key)

    account.exam_results.joins(:exam_type).where(exam_types: { key: metric_key }).recent_first.first&.unit
  end

  def metric_label
    return I18n.t("goals.metrics.weight") if metric_key == "weight"

    exam_type&.name || I18n.t("measurements.keys.#{metric_key}", default: metric_key.to_s.humanize)
  end
end
