module HabitsHelper
  # Classes Tailwind do badge de força do hábito.
  STRENGTH_BADGE_CLASSES = {
    strong: "bg-emerald-100 text-emerald-700",
    medium: "bg-amber-100 text-amber-700",
    weak: "bg-slate-200 text-slate-600",
    new: "bg-slate-100 text-slate-500"
  }.freeze

  def strength_badge_class(strength)
    STRENGTH_BADGE_CLASSES.fetch(strength, STRENGTH_BADGE_CLASSES[:new])
  end

  def strength_label(strength)
    t("habits.strength.#{strength}")
  end

  # Texto da cadência: regra automática, "Todos os dias", "Seg, Qua, Sex" ou "3x/sem".
  def cadence_label(habit)
    if habit.auto?
      auto_rule_label(habit)
    elsif habit.weekly_count?
      t("habits.times_per_week", count: habit.weekly_target)
    elsif habit.daily?
      t("habits.everyday")
    else
      Array(habit.weekdays).sort.map { |d| t("date.abbr_day_names")[d].capitalize }.join(", ")
    end
  end

  # Regra de um hábito automático em texto: "Tela ≤ 3 h", "Sono ≥ 7 h",
  # "Hora de dormir ≤ 00:30", "Rede social ≤ 2 h (3 apps)".
  def auto_rule_label(habit)
    metric = t("habits.auto_metrics.#{habit.metric_key}", default: habit.metric_key.to_s.humanize)
    operator = habit.comparator == "lte" ? "≤" : "≥"
    meta = habit.auto_metric

    value =
      if habit.time_of_day_metric?
        format("%02d:%02d", habit.threshold_value.to_i / 60, habit.threshold_value.to_i % 60)
      else
        v = habit.threshold_value
        v = v.to_i if v && v.to_i == v
        "#{v} #{meta[:unit]}".strip
      end

    label = "#{metric} #{operator} #{value}".strip
    label += " (#{Array(habit.app_bundle_ids).size} apps)" if habit.app_filtered? && habit.app_bundle_ids.present?
    label
  end
end
