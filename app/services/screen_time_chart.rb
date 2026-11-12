# Monta as barras do gráfico de tempo de tela a partir do total por dia.
#
# - Períodos longos começam no primeiro dia COM dado (um filtro de "7 meses" com
#   1 mês de histórico não vira um gráfico quase todo vazio).
# - Até DAILY_LIMIT dias: uma barra por dia. Acima disso: uma barra por semana
#   (segunda a domingo) com a MÉDIA diária dos dias com dado — comparável com a
#   linha da média e legível em períodos longos.
#
# Cada barra: { from:, to:, seconds:, days:, label:, weekly: }.
class ScreenTimeChart
  DAILY_LIMIT = 45

  attr_reader :bars, :from, :to

  def initialize(by_date, from:, to:)
    @by_date = by_date
    @from = from
    @to = to
    # Só encurta períodos longos; "7 dias" continua mostrando os 7 dias.
    first = by_date.keys.min
    @from = [from, first].max if first && span_days > DAILY_LIMIT
    @bars = span_days <= DAILY_LIMIT ? daily_bars : weekly_bars
  end

  def weekly?
    span_days > DAILY_LIMIT
  end

  def max
    @bars.map { |b| b[:seconds] }.max || 0
  end

  private

  def span_days
    (@to - @from).to_i + 1
  end

  def daily_bars
    count = span_days
    (@from..@to).map do |date|
      { from: date, to: date, seconds: @by_date[date] || 0, days: @by_date.key?(date) ? 1 : 0,
        label: daily_label(date, count), weekly: false }
    end
  end

  # ≤7 dias: inicial do dia da semana; ≤16: dia do mês; acima: dia 1 vira o mês
  # (ex.: "nov") e os múltiplos de 5 mostram o dia.
  def daily_label(date, count)
    if count <= 7 then I18n.t("date.abbr_day_names")[date.wday].first(1).upcase
    elsif count <= 16 then date.day.to_s
    elsif date.day == 1 then month_abbr(date)
    elsif (date.day % 5).zero? && date.day < 30 then date.day.to_s
    end
  end

  def weekly_bars
    last_month = nil
    (@from..@to).group_by(&:beginning_of_week).sort.map do |_, dates|
      values = dates.filter_map { |d| @by_date[d] }
      label = dates.first.month == last_month ? nil : month_abbr(dates.first)
      last_month = dates.first.month
      { from: dates.first, to: dates.last, seconds: values.empty? ? 0 : values.sum / values.size,
        days: values.size, label: label, weekly: true }
    end
  end

  def month_abbr(date)
    I18n.t("date.abbr_month_names")[date.month].to_s.delete(".").downcase
  end
end
