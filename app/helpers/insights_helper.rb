module InsightsHelper
  # Rótulo da métrica analisada (reusa os nomes dos hábitos automáticos).
  def insight_metric_label(metric_key)
    t("habits.auto_metrics.#{metric_key}", default: metric_key.to_s.humanize)
  end

  # Texto qualitativo da correlação de Pearson: força + direção.
  def correlation_label(coefficient)
    magnitude = coefficient.abs
    strength =
      if magnitude >= 0.5 then t("insights.strength.strong")
      elsif magnitude >= 0.3 then t("insights.strength.moderate")
      elsif magnitude >= 0.1 then t("insights.strength.weak")
      else t("insights.strength.none")
      end
    return strength if magnitude < 0.1

    direction = coefficient.positive? ? t("insights.direction.positive") : t("insights.direction.negative")
    "#{strength} · #{direction}"
  end

  # Cor do badge conforme a diferença de aderência (pontos percentuais).
  def diff_badge_class(diff)
    if diff.positive? then "bg-emerald-100 text-emerald-700"
    elsif diff.negative? then "bg-rose-100 text-rose-700"
    else "bg-slate-100 text-slate-600"
    end
  end
end
