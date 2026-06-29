class Goal < ApplicationRecord
  belongs_to :account

  # Métricas alvo: peso (weight_entries) + qualquer métrica do catálogo de saúde.
  METRIC_KEYS = (["weight"] + Measurement::CATALOG.keys).freeze

  validates :name, presence: true
  validates :metric_key, presence: true, inclusion: { in: METRIC_KEYS }
  validates :target_value, presence: true, numericality: true
  validates :start_value, numericality: true, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }

  def unit
    return "kg" if metric_key == "weight"

    Measurement.meta(metric_key)[:unit]
  end

  def metric_label
    return I18n.t("goals.metrics.weight") if metric_key == "weight"

    I18n.t("measurements.keys.#{metric_key}", default: metric_key.to_s.humanize)
  end
end
