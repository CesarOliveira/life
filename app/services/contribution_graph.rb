# Monta o grid estilo "contribuições do GitHub": uma célula por dia, colorida
# pela quantidade de hábitos concluídos naquele dia (no escopo da conta).
class ContributionGraph
  # Classes Tailwind por nível de intensidade (0 = vazio ... 4 = máximo).
  CELL_CLASSES = %w[bg-slate-100 bg-emerald-200 bg-emerald-400 bg-emerald-600 bg-emerald-800].freeze

  Cell = Struct.new(:date, :count, :level, :names, keyword_init: true)

  # Aceita um intervalo explícito (from:/to:) — usado pela página de Atividade — ou,
  # por compatibilidade, today:/weeks: (janela rolante terminando em `today`, usada
  # no dashboard). Dias futuros (> today) e fora do intervalo [from, to] vêm como
  # nil (célula vazia), igual ao GitHub.
  def initialize(account, from: nil, to: nil, today: Date.current, weeks: 53, habit: nil)
    @account = account
    @habit = habit
    @today = today
    @to = to || today
    @from = from || (week_start(@to) - (weeks - 1) * 7)
    @visible_to = [@to, @today].min
    @start = week_start(@from)
    # A grade termina na semana de HOJE (sem colunas/meses futuros).
    @weeks = ((@visible_to - @start).to_i / 7) + 1
    @counts = load_counts
    @names = load_names
    @max = @counts.values.max || 0
  end

  # Colunas (semanas) da mais antiga (esq.) à atual (dir.). Cada coluna tem 7
  # células (domingo..sábado); datas fora do intervalo ou futuras vêm como nil.
  def columns
    (0...@weeks).map do |w|
      col_start = @start + (w * 7)
      (0..6).map do |d|
        date = col_start + d
        next nil if date < @from || date > @visible_to

        count = @counts[date] || 0
        Cell.new(date: date, count: count, level: level_for(count), names: @names[date] || [])
      end
    end
  end

  # Segmentos de mês para os rótulos do topo: [{label:, weeks:}, ...].
  def month_segments
    segs = []
    @weeks.times do |w|
      m = (@start + (w * 7)).month
      if segs.empty? || segs.last[:month] != m
        segs << { month: m, label: I18n.t("date.abbr_month_names")[m].to_s.capitalize, weeks: 1 }
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
    checks_scope.group(:date).count
  end

  # Nomes dos hábitos concluídos por dia (para o tooltip da célula).
  def load_names
    checks_scope.order("habits.name").pluck(:date, "habits.name")
                .group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  def checks_scope
    scope = HabitCheck.joins(:habit).where(habits: { account_id: @account.id })
    scope = scope.where(habit_id: @habit.id) if @habit
    scope.where(date: @from..@visible_to)
  end

  def level_for(count)
    return 0 if count <= 0
    return count.clamp(1, 4) if @max <= 4

    ((count * 4.0 / @max).ceil).clamp(1, 4)
  end
end
