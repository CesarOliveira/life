# Conta de demonstração com ~30 dias de dados plausíveis: tempo de tela (com
# blocos de 15 min), saúde do iPhone/Watch, treinos, hábitos, tarefas e peso.
# Serve para as capturas de tela da App Store e para o revisor da Apple entrar
# no app (exigência da revisão quando há login).
#
# Idempotente: rodar de novo apaga os dados da conta demo e recria. Nunca toca
# em outra conta. Uso: bin/rails demo:seed EMAIL=... PASSWORD=...
class DemoAccount
  DAYS = 30
  APPS = [["Instagram", 70], ["WhatsApp", 45], ["YouTube", 25], ["Safari", 18], ["Spotify", 12], ["Mapas", 6], ["Notas", 5]].freeze
  WORKOUTS = [["running", 2100, 5200, 360], ["strength_training", 2700, nil, 280], ["walking", 1800, 2400, 140], ["cycling", 3000, 14_000, 420]].freeze

  def initialize(email:, password:, name: "Ana Souza", today: Date.current)
    @email = email.to_s.strip.downcase
    @password = password.to_s
    @name = name
    @today = today
    @random = Random.new(2026)
  end

  def call
    raise ArgumentError, "senha de no mínimo 12 caracteres" if @password.length < 12

    ActiveRecord::Base.transaction do
      user = User.find_or_initialize_by(email: @email)
      # Só mexe em e-mails de demonstração: nunca sobrescreve um usuário real.
      raise ArgumentError, "use um e-mail com 'demo' (ex.: demo@...)" unless @email.split("@").first.include?("demo")

      user.name = @name
      user.password = @password
      user.save!
      account = Account.ensure_personal_for(user)
      account.update!(name: @name, height_cm: 168)
      reset(account)
      seed(account, user)
      account
    end
  end

  private

  def reset(account)
    account.task_boards.destroy_all
    account.habits.destroy_all
    [account.app_usages, account.app_usage_slots, account.measurements, account.workouts, account.weight_entries].each(&:delete_all)
  end

  def seed(account, user)
    days = (1..DAYS).map { |i| @today - i }
    days.each { |day| seed_day(account, day) }
    seed_workouts(account)
    seed_habits(account, days)
    seed_tasks(account, user)
  end

  def jitter(base, spread) = base + @random.rand(-spread.to_f..spread.to_f)

  def seed_day(account, day)
    weekend = day.saturday? || day.sunday?
    usages = []
    slots = []
    APPS.each do |name, minutes|
      total = (jitter(minutes * (weekend ? 1.3 : 1.0), minutes * 0.35) * 60).round.clamp(60, 6 * 3600)
      usages << { account_id: account.id, device: "iphone", date: day, bundle_id: name, name: name, seconds: total }
      spread_into_slots(total).each do |slot, seconds|
        slots << { account_id: account.id, device: "iphone", date: day, slot: slot, bundle_id: name, name: name, seconds: seconds }
      end
    end
    AppUsage.insert_all(usages, record_timestamps: true)
    AppUsageSlot.upsert_all(merge_slots(slots), unique_by: :idx_app_usage_slots_unique, record_timestamps: true)

    bedtime = (23 * 60) + jitter(10, 35).round
    sleep = jitter(430, 40).round
    metrics = {
      "sleep_minutes" => sleep, "sleep_bedtime" => bedtime % 1440, "sleep_wake" => (bedtime + sleep + 15) % 1440,
      "sleep_deep_minutes" => (sleep * jitter(0.16, 0.03)).round, "sleep_rem_minutes" => (sleep * jitter(0.22, 0.03)).round,
      "sleep_core_minutes" => (sleep * jitter(0.55, 0.04)).round, "sleep_awake_minutes" => jitter(18, 8).round,
      "steps" => jitter(weekend ? 6500 : 9000, 2500).round, "active_energy" => jitter(520, 140).round,
      "exercise_minutes" => jitter(38, 20).round.clamp(3, 120), "stand_hours" => jitter(10, 2).round.clamp(4, 16),
      "move_goal" => 550, "exercise_goal" => 30, "stand_goal" => 12, "distance_km" => jitter(6.2, 2).round(1),
      "resting_hr" => jitter(58, 3).round, "hrv" => jitter(52, 9).round, "hr_avg" => jitter(74, 4).round,
      "spo2" => jitter(97, 1).round(1), "respiratory_rate" => jitter(14.5, 1).round(1), "vo2max" => jitter(41.5, 0.4).round(1)
    }
    metrics["rings_closed"] = [metrics["active_energy"] >= 550, metrics["exercise_minutes"] >= 30, metrics["stand_hours"] >= 12].count(true)
    rows = metrics.map do |key, value|
      meta = Measurement.meta(key)
      { account_id: account.id, key: key, value: value, unit: meta[:unit], measured_on: day, category: "health", source: "api" }
    end
    Measurement.insert_all(rows, record_timestamps: true)
    account.weight_entries.create!(date: day, weight_kg: jitter(64.5, 0.6).round(1)) if (day.yday % 3).zero?
  end

  # Distribui o uso do dia em blocos de 15 min, concentrado em manhã, almoço e noite.
  def spread_into_slots(total)
    peaks = [[31, 4], [49, 3], [80, 6], [91, 3]] # 07:45, 12:15, 20:00, 22:45
    out = Hash.new(0)
    remaining = total
    while remaining.positive?
      center, width = peaks[@random.rand(peaks.size)]
      slot = (center + @random.rand(-width..width)).clamp(0, AppUsageSlot::SLOTS_PER_DAY - 1)
      chunk = [remaining, @random.rand(120..600)].min
      out[slot] += chunk
      remaining -= chunk
    end
    out.transform_values { |s| s.clamp(0, 900) }
  end

  def merge_slots(rows)
    rows.group_by { |r| [r[:date], r[:slot], r[:bundle_id]] }.map do |_, list|
      list.first.merge(seconds: list.sum { |r| r[:seconds] }.clamp(0, 900))
    end
  end

  def seed_workouts(account)
    (1..DAYS).step(2).each_with_index do |offset, index|
      activity, duration, distance, kcal = WORKOUTS[index % WORKOUTS.size]
      start = (@today - offset).in_time_zone.change(hour: 7, min: 10)
      account.workouts.create!(uuid: "demo-#{offset}", activity: activity, started_at: start, ended_at: start + duration, date: start.to_date,
                               duration_seconds: duration, distance_m: distance, energy_kcal: kcal, avg_hr: jitter(138, 8).round,
                               max_hr: jitter(165, 6).round, source: "Apple Watch")
    end
  end

  def seed_habits(account, days)
    category = account.habit_categories.ordered.first
    manual = [["Ler 20 minutos", "#0ea5e9", 0.7], ["Meditar", "#a855f7", 0.55], ["Beber 2 L de água", "#06b6d4", 0.8]].map do |name, color, rate|
      habit = account.habits.create!(name: name, color: color, habit_category: category, frequency: "weekly_days", weekdays: Habit::WEEKDAYS)
      days.each { |day| habit.habit_checks.create!(date: day) if @random.rand < rate }
      habit
    end
    tela = account.habits.create!(name: "Tela abaixo de 3 h", color: "#10b981", habit_category: category, auto: true,
                                  metric_key: "screen_time_total", comparator: "lte", threshold_value: 3)
    exercicio = account.habits.create!(name: "30 min de exercício", color: "#84cc16", habit_category: category, auto: true,
                                       metric_key: "exercise_minutes", comparator: "gte", threshold_value: 30)
    [tela, exercicio].each { |habit| HabitRuleEvaluator.new(account).backfill(habit, from: days.last, to: @today) }
    manual.first.habit_checks.find_or_create_by!(date: @today)
  end

  def seed_tasks(account, user)
    board = TaskBoard.create_with_columns!(account: account, name: "Pessoal")
    todo, doing, _qa, done = board.columns.to_a
    [
      [todo, "Marcar check-up anual", "Pedir hemograma, colesterol e vitamina D.", @today + 5],
      [todo, "Renovar a CNH", nil, @today - 1],
      [todo, "Comprar presente da Júlia", nil, @today + 9],
      [doing, "Planejar a viagem de dezembro", "Comparar voos e reservar a pousada.", nil],
      [done, "Trocar o filtro de água", nil, nil]
    ].each do |column, title, description, due|
      task = board.tasks.create!(account: account, task_column: column, creator: user, title: title, description: description,
                                 due_on: due, completed_at: column.done ? 2.days.ago : nil)
      task.comments.create!(user: user, body: "Ver horários de manhã.") if title.start_with?("Marcar")
    end
  end
end
