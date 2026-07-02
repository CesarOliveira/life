# Calcula o progresso de uma meta de alvo: lê o histórico da métrica (peso ou
# medições), determina o valor atual e a % do caminho de start_value até
# target_value (em qualquer direção: emagrecer ou aumentar).
class GoalProgress
  def initialize(goal)
    @goal = goal
    @series = load_series
  end

  def data?
    @series.any?
  end

  def current_value
    @series.last&.fetch(:value)
  end

  def start_value
    @goal.start_value || @series.first&.fetch(:value)
  end

  def target_value
    @goal.target_value
  end

  def unit
    @goal.unit
  end

  # :down (emagrecer/reduzir) ou :up (aumentar) conforme alvo vs. início.
  def direction
    base = start_value || target_value
    target_value < base ? :down : :up
  end

  def achieved?
    return false if current_value.nil?

    meets_target?(current_value)
  end

  # Data em que o alvo foi atingido pela primeira vez (do histórico), se houver.
  def achieved_on
    @series.find { |point| meets_target?(point[:value]) }&.fetch(:date)
  end

  # % do caminho de start até target (0..100).
  def progress_pct
    return 0 if current_value.nil? || start_value.nil?

    span = (target_value - start_value).to_f
    return achieved? ? 100 : 0 if span.zero?

    (((current_value - start_value).to_f / span) * 100).clamp(0, 100).round
  end

  def remaining
    return nil if current_value.nil?

    (target_value - current_value).abs
  end

  private

  def meets_target?(value)
    direction == :down ? value <= target_value : value >= target_value
  end

  def load_series
    if @goal.metric_key == "weight"
      @goal.account.weight_entries.chronological.map { |e| { date: e.date, value: e.weight_kg } }
    elsif (type = @goal.exam_type)
      @goal.account.exam_results.where(exam_type: type).chronological.map { |r| { date: r.measured_on, value: r.value } }
    else
      @goal.account.measurements.for_key(@goal.metric_key).chronological.map { |m| { date: m.measured_on, value: m.value } }
    end
  end
end
