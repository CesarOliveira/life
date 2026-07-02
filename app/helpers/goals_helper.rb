module GoalsHelper
  # Rótulo de uma métrica de meta no seletor: peso ou uma chave do catálogo.
  def goal_metric_label(metric_key)
    return t("goals.metrics.weight") if metric_key == "weight"
    return t("measurements.keys.#{metric_key}") if Measurement::CATALOG.key?(metric_key.to_s)

    ExamType.find_by(key: metric_key)&.name || metric_key.to_s.humanize
  end
end
