# Resumo do dia para a tela inicial NATIVA do app: última noite, atividade,
# coração, tempo de tela, tarefas em aberto e hábitos de hoje. Uma chamada só.
class MobileSummary
  ACTIVITY_KEYS = %w[steps exercise_minutes active_energy stand_hours distance_km move_goal exercise_goal stand_goal].freeze
  SLEEP_STAGES = %w[sleep_deep_minutes sleep_core_minutes sleep_rem_minutes sleep_awake_minutes].freeze
  TASKS_SHOWN = 6

  def initialize(account, user: nil, today: Date.current)
    @account = account
    @user = user
    @today = today
  end

  def as_json(*)
    {
      date: @today,
      user: { name: @user&.name, email: @user&.email },
      sleep: sleep,
      activity: activity,
      heart: heart,
      screen_time: screen_time,
      tasks: tasks,
      habits: habits
    }
  end

  private

  def latest(key)
    @account.measurements.where(category: "health", key: key).order(measured_on: :desc).first
  end

  def values_on(date, keys)
    @account.measurements.where(category: "health", key: keys, measured_on: date).to_h { |m| [m.key, m.value.to_f] }
  end

  def clock(minutes)
    minutes && format("%02d:%02d", minutes.to_i / 60, minutes.to_i % 60)
  end

  def number(value)
    return nil if value.nil?

    value = value.to_f.round(1)
    value == value.to_i ? value.to_i : value
  end

  def sleep
    night = latest("sleep_minutes")
    return nil if night.nil?

    extra = values_on(night.measured_on, %w[sleep_bedtime sleep_wake] + SLEEP_STAGES)
    { date: night.measured_on, minutes: night.value.to_i, bedtime: clock(extra["sleep_bedtime"]), wake: clock(extra["sleep_wake"]),
      stages: SLEEP_STAGES.filter_map { |key| extra[key] && { key: key, name: Measurement.key_label(key), minutes: extra[key].to_i } } }
  end

  def activity
    day = latest("steps")&.measured_on || latest("active_energy")&.measured_on
    return nil if day.nil?

    values = values_on(day, ACTIVITY_KEYS)
    { date: day, steps: number(values["steps"]), exercise_minutes: number(values["exercise_minutes"]),
      active_energy: number(values["active_energy"]), stand_hours: number(values["stand_hours"]), distance_km: number(values["distance_km"]),
      move_goal: number(values["move_goal"]), exercise_goal: number(values["exercise_goal"]), stand_goal: number(values["stand_goal"]) }.compact
  end

  def heart
    resting = latest("resting_hr")
    hrv = latest("hrv")
    return nil if resting.nil? && hrv.nil?

    { resting_hr: number(resting&.value), resting_hr_date: resting&.measured_on, hrv: number(hrv&.value), hrv_date: hrv&.measured_on }.compact
  end

  def screen_time
    day = @account.app_usages.maximum(:date)
    return nil if day.nil?

    usages = @account.app_usages.where(date: day)
    names = usages.where.not(name: nil).group(:bundle_id).maximum(:name)
    week = @account.app_usages.where(date: (day - 6)..day).group(:date).sum(:seconds)
    { date: day, minutes: (usages.sum(:seconds) / 60.0).round,
      average_7d_minutes: week.empty? ? nil : (week.values.sum / week.size / 60.0).round,
      top_apps: usages.group(:bundle_id).sum(:seconds).sort_by { |_, s| -s }.first(3)
                      .map { |bundle, seconds| { app: names[bundle].presence || bundle, minutes: (seconds / 60.0).round } } }.compact
  end

  def tasks
    open = @account.tasks.where(completed_at: nil)
    items = open.includes(:task_board, :task_column).order(Arel.sql("due_on IS NULL, due_on, updated_at DESC")).limit(TASKS_SHOWN)
    { open: open.count, overdue: open.where(due_on: ...@today).count,
      items: items.map { |t| { number: t.number, title: t.title, board: t.task_board.name, column: t.task_column.name, due_on: t.due_on, overdue: t.overdue? }.compact } }
  end

  def habits
    list = @account.habits.where(active: true).includes(:habit_checks).order(:position, :created_at).select { |h| h.scheduled_on?(@today) }
    list.map { |h| { id: h.id, name: h.name, color: h.color, automatic: h.auto, done: h.checked_on?(@today) } }
  end
end
