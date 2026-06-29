# Avalia hábitos automáticos (de limiar) e mantém os `HabitCheck` em dia: cria a
# marcação quando a regra é satisfeita, remove quando deixa de ser. Dias sem dado
# da métrica são ignorados (não punem o streak).
#
# Disparado após a ingestão (tela via AppUsage, sono/passos via Measurement) e ao
# criar/editar um hábito automático (para preencher o histórico recente).
class HabitRuleEvaluator
  def initialize(account)
    @account = account
  end

  # Reavalia todos os hábitos auto da conta nas datas informadas.
  def evaluate(dates)
    habits = @account.habits.automatic.to_a
    return if habits.empty?

    Array(dates).compact.uniq.each do |date|
      habits.each { |habit| evaluate_habit(habit, date) }
    end
  end

  # Reavalia um hábito numa janela [from, to] (ex.: ao criar/editar).
  def backfill(habit, from:, to:)
    return unless habit.auto?

    (from..to).each { |date| evaluate_habit(habit, date) }
  end

  private

  def evaluate_habit(habit, date)
    value = metric_value(habit, date)
    return if value.nil? # sem dados: não mexe na marcação

    check = habit.habit_checks.find_by(date: date)
    if satisfied?(habit, value)
      habit.habit_checks.create!(date: date) unless check
    elsif check
      check.destroy
    end
  rescue ActiveRecord::RecordNotUnique
    # corrida rara: já existe a marcação do dia — ok.
  end

  def satisfied?(habit, value)
    case habit.comparator
    when "lte" then value <= habit.threshold_value
    when "gte" then value >= habit.threshold_value
    else false
    end
  end

  # Valor da métrica do hábito naquele dia, ou nil se não houver dado.
  def metric_value(habit, date)
    meta = habit.auto_metric
    case meta[:source]
    when :app_usage
      usages = @account.app_usages.where(date: date)
      return nil unless usages.exists?

      usages.sum(:seconds) / 3600.0
    when :measurement
      measurement = @account.measurements.find_by(key: meta[:measurement_key], measured_on: date)
      return nil unless measurement

      measurement.value.to_f * (meta[:scale] || 1)
    end
  end
end
