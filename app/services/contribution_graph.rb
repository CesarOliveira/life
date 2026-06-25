# Monta o grid estilo "contribuições do GitHub": uma célula por dia, colorida
# pela quantidade de hábitos concluídos naquele dia (no escopo da conta).
class ContributionGraph
  MONTHS = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze
  # Classes Tailwind por nível de intensidade (0 = vazio ... 4 = máximo).
  CELL_CLASSES = %w[bg-slate-100 bg-emerald-200 bg-emerald-400 bg-emerald-600 bg-emerald-800].freeze

  Cell = Struct.new(:date, :count, :level, keyword_init: true)

  def initialize(account, today: Date.current, weeks: 53)
    @account = account
    @today = today
    @weeks = weeks
    @start = week_start(today) - (weeks - 1) * 7
    @counts = load_counts
    @max = @counts.values.max || 0
  end

  # Colunas (semanas) da mais antiga (esq.) à atual (dir.). Cada coluna tem 7
  # células (domingo..sábado); datas futuras vêm como nil.
  def columns
    (0...@weeks).map do |w|
      col_start = @start + (w * 7)
      (0..6).map do |d|
        date = col_start + d
        next nil if date > @today

        count = @counts[date] || 0
        Cell.new(date: date, count: count, level: level_for(count))
      end
    end
  end

  # Segmentos de mês para os rótulos do topo: [{label:, weeks:}, ...].
  def month_segments
    segs = []
    @weeks.times do |w|
      m = (@start + (w * 7)).month
      if segs.empty? || segs.last[:month] != m
        segs << { month: m, label: MONTHS[m - 1], weeks: 1 }
      else
        segs.last[:weeks] += 1
      end
    end
    segs
  end

  def total
    @counts.values.sum
  end

  def cell_class(level)
    CELL_CLASSES[level]
  end

  private

  def week_start(date)
    date - date.wday # alinha no domingo
  end

  def load_counts
    HabitCheck.joins(:habit)
              .where(habits: { account_id: @account.id })
              .where(date: @start..@today)
              .group(:date)
              .count
  end

  def level_for(count)
    return 0 if count <= 0
    return count.clamp(1, 4) if @max <= 4

    ((count * 4.0 / @max).ceil).clamp(1, 4)
  end
end
