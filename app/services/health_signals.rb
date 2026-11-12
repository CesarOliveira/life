# Monta a aba "Sinais" da Saúde: cartões por métrica (com média, variação e
# série curta), resumo do último dia, sono da última noite, anéis e treinos.
#
# Lê só os últimos WINDOW dias: com ~70 métricas por dia, carregar o histórico
# inteiro a cada abertura da página não escala.
class HealthSignals
  WINDOW = 90       # dias carregados (histórico dos cartões)
  SPARK_DAYS = 30   # dias da série curta
  BASELINE = 7      # dias anteriores usados como referência da variação
  SUMMARY_KEYS = %w[sleep_minutes steps exercise_minutes active_energy resting_hr hrv].freeze
  SLEEP_STAGES = %w[sleep_deep_minutes sleep_core_minutes sleep_rem_minutes sleep_awake_minutes].freeze
  RINGS = [
    { key: "active_energy", goal: "move_goal", name: "move" },
    { key: "exercise_minutes", goal: "exercise_goal", name: "exercise" },
    { key: "stand_hours", goal: "stand_goal", name: "stand" }
  ].freeze

  def initialize(account, today: Date.current)
    @account = account
    @today = today
    @rows = account.measurements.where(category: "health", measured_on: (today - WINDOW)..).chronological.to_a
    @by_key = @rows.group_by(&:key)
  end

  # [{ key:, label:, unit:, section:, latest:, rows:, spark:, avg7:, avg30:, delta:, trend: }, ...]
  # na ordem do catálogo.
  def groups
    @groups ||= @by_key.map { |key, rows| build_group(key, rows) }
                       .sort_by { |g| [Measurement.catalog_position(g[:key]), g[:label]] }
  end

  def sections
    groups.group_by { |g| g[:section] }
  end

  # Destaques do topo: só as métricas que existem.
  def summary
    index = groups.index_by { |g| g[:key] }
    SUMMARY_KEYS.filter_map { |key| index[key] }
  end

  # Última noite com sono: { date:, minutes:, bedtime:, wake:, stages: [{ key:, minutes:, pct: }] }.
  def last_night
    latest = @by_key["sleep_minutes"]&.last
    return nil if latest.nil?

    on = ->(key) { @by_key[key]&.find { |m| m.measured_on == latest.measured_on } }
    stages = SLEEP_STAGES.filter_map { |key| (m = on.call(key)) && { key: key, minutes: m.value.to_i } }
    total = stages.sum { |s| s[:minutes] }
    stages.each { |s| s[:pct] = total.zero? ? 0 : (s[:minutes] * 100.0 / total).round(1) }
    { date: latest.measured_on, minutes: latest.value.to_i, bedtime: on.call("sleep_bedtime"), wake: on.call("sleep_wake"), stages: stages }
  end

  # Anéis do Watch no dia mais recente: [{ name:, value:, goal:, pct:, unit: }]. Sem meta, pct fica nil.
  def rings
    date = @by_key["active_energy"]&.last&.measured_on
    return [] if date.nil?

    value_on = ->(key) { @by_key[key]&.find { |m| m.measured_on == date }&.value }
    RINGS.filter_map do |ring|
      value = value_on.call(ring[:key])
      next if value.nil?

      goal = value_on.call(ring[:goal])
      pct = goal&.positive? ? (value * 100.0 / goal).round : nil
      { name: ring[:name], key: ring[:key], date: date, value: value, goal: goal, pct: pct }
    end
  end

  def workouts(limit: 8)
    @account.workouts.recent_first.limit(limit).to_a
  end

  private

  def build_group(key, rows)
    latest = rows.last
    values_since = ->(days) { rows.select { |m| m.measured_on > latest.measured_on - days }.map { |m| m.value.to_f } }
    baseline = rows.select { |m| m.measured_on < latest.measured_on && m.measured_on >= latest.measured_on - BASELINE }
                   .map { |m| m.value.to_f }
    delta = delta_pct(key, latest.value.to_f, baseline)
    {
      key: key, label: latest.label, unit: latest.unit, section: Measurement.section(key),
      latest: latest, rows: rows.reverse,
      spark: rows.select { |m| m.measured_on > @today - SPARK_DAYS }.map { |m| { date: m.measured_on, value: m.value.to_f } },
      avg7: mean(values_since.call(7)), avg30: mean(values_since.call(30)),
      delta: delta, trend: trend(key, delta)
    }
  end

  def mean(values)
    values.empty? ? nil : values.sum / values.size
  end

  # Variação (%) do último valor contra a média dos BASELINE dias anteriores.
  # Horários (hora de dormir/acordar) não têm variação percentual que faça sentido.
  def delta_pct(key, value, baseline)
    return nil if baseline.size < 2 || Measurement::TIME_KEYS.include?(key)

    avg = mean(baseline)
    return nil if avg.zero?

    ((value - avg) * 100.0 / avg.abs).round
  end

  def trend(key, delta)
    return :neutral if delta.nil? || delta.zero? || Measurement::NEUTRAL_TREND.include?(key)

    lower_better = Measurement::LOWER_IS_BETTER.include?(key)
    (delta.negative? == lower_better) ? :good : :bad
  end
end
