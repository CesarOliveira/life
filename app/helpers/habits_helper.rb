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

  # Regra de um hábito automático em texto: "Tela ≤ 3 h", "Sono ≥ 7 h".
  def auto_rule_label(habit)
    metric = t("habits.auto_metrics.#{habit.metric_key}", default: habit.metric_key.to_s.humanize)
    operator = habit.comparator == "lte" ? "≤" : "≥"
    value = habit.threshold_value
    value = value.to_i if value && value.to_i == value
    "#{metric} #{operator} #{value} #{habit.auto_metric[:unit]}".strip
  end
end
