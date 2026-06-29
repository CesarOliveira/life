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

  # Texto da cadência: "Todos os dias", "Seg, Qua, Sex" ou "3x por semana".
  def cadence_label(habit)
    if habit.weekly_count?
      t("habits.times_per_week", count: habit.weekly_target)
    elsif habit.daily?
      t("habits.everyday")
    else
      Array(habit.weekdays).sort.map { |d| t("date.abbr_day_names")[d].capitalize }.join(", ")
    end
  end
end
