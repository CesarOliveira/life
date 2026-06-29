module GoalsHelper
  # Rótulo de uma métrica de meta no seletor: peso ou uma chave do catálogo.
  def goal_metric_label(metric_key)
    return t("goals.metrics.weight") if metric_key == "weight"

    t("measurements.keys.#{metric_key}", default: metric_key.to_s.humanize)
  end
end
