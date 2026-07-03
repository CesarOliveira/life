# Análise cruzada: relaciona uma métrica de saúde (sono, passos, tela, FC) com a
# aderência diária aos hábitos manuais, usando (conta, data) como chave comum.
# Para cada dia com dado da métrica E hábitos agendados, calcula a % de hábitos
# concluídos; depois mede a correlação (Pearson) e compara dias acima x abaixo da
# mediana da métrica. Ex.: "dias com mais sono → maior aderência".
class CrossAnalysis
  METRICS = Habit::AUTO_METRICS.keys.freeze
  # Mínimo de dias pareados (métrica + hábitos) para a análise valer algo:
  # com menos que isso, correlação de Pearson é praticamente ruído.
  MIN_DAYS = 10

  Result = Struct.new(
    :metric_key, :unit, :n, :correlation, :median, :above_avg, :below_avg,
    keyword_init: true
  ) do
    def enough?
      n >= CrossAnalysis::MIN_DAYS
    end

    # Diferença de aderência (pontos percentuais) entre dias acima e abaixo da mediana.
    def diff
      return nil unless above_avg && below_avg

      (above_avg - below_avg).round
    end
  end

  def initialize(account, metric_key, from:, to:)
    @account = account
    @metric_key = METRICS.include?(metric_key) ? metric_key : METRICS.first
    @from = from
    @to = to
  end

  attr_reader :metric_key

  def call
    series = build_series
    metric_values = series.map { |point| point[:metric] }
    rates = series.map { |point| point[:rate] }

    result = Result.new(metric_key: @metric_key, unit: unit, n: series.size)
    return result if series.size < MIN_DAYS

    med = median(metric_values)
    above = series.select { |point| point[:metric] >= med }.map { |point| point[:rate] }
    below = series.select { |point| point[:metric] < med }.map { |point| point[:rate] }

    result.correlation = pearson(metric_values, rates)
    result.median = med
    result.above_avg = average(above)
    result.below_avg = average(below)
    result
  end

  private

  def unit
    Habit::AUTO_METRICS[@metric_key][:unit]
  end

  # [{ date:, metric:, rate: }] para dias com métrica e hábitos agendados.
  def build_series
    habits = @account.habits.active.where(auto: false, frequency: "weekly_days").to_a
    return [] if habits.empty?

    done_by_date = Hash.new { |hash, key| hash[key] = Set.new }
    HabitCheck.where(habit_id: habits.map(&:id), date: @from..@to)
              .pluck(:habit_id, :date)
              .each { |habit_id, date| done_by_date[date] << habit_id }

    metric_by_date = load_metric_by_date

    (@from..@to).filter_map do |date|
      metric = metric_by_date[date]
      next if metric.nil?

      scheduled = habits.select { |habit| habit.scheduled_on?(date) }
      next if scheduled.empty?

      done = scheduled.count { |habit| done_by_date[date].include?(habit.id) }
      { date: date, metric: metric, rate: done * 100.0 / scheduled.size }
    end
  end

  def load_metric_by_date
    meta = Habit::AUTO_METRICS[@metric_key]
    case meta[:source]
    when :app_usage
      @account.app_usages.where(date: @from..@to).group(:date).sum(:seconds)
              .transform_values { |seconds| seconds / 3600.0 }
    when :measurement
      @account.measurements.where(key: meta[:measurement_key], measured_on: @from..@to)
              .pluck(:measured_on, :value).to_h
              .transform_values { |value| value.to_f * (meta[:scale] || 1) }
    end
  end

  def pearson(xs, ys)
    n = xs.size
    return 0.0 if n < 2

    sx = xs.sum
    sy = ys.sum
    sxx = xs.sum { |x| x * x }
    syy = ys.sum { |y| y * y }
    sxy = xs.each_index.sum { |i| xs[i] * ys[i] }

    numerator = (n * sxy) - (sx * sy)
    denominator = Math.sqrt(((n * sxx) - (sx**2)) * ((n * syy) - (sy**2)))
    denominator.zero? ? 0.0 : (numerator / denominator).round(2)
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def average(values)
    return nil if values.empty?

    (values.sum / values.size).round
  end
end
