# Estatísticas de um hábito (sequência/streak, adesão e força), calculadas a
# partir das datas marcadas. Carrega as datas uma vez para evitar N+1.
# Entende as duas cadências: dias específicos (weekly_days) e Nx por semana
# (weekly_count).
class HabitStats
  STRENGTH_WINDOW = 28 # dias para classificar a força (~4 semanas)
  STRONG_MIN = 80      # % de adesão para "Forte"
  MEDIUM_MIN = 50      # % de adesão para "Médio"
  MIN_HISTORY_DAYS = 6 # antes disso o hábito é "Novo" (sem histórico suficiente)

  def initialize(habit, today: Date.current)
    @habit = habit
    @today = today
    @checked = habit.habit_checks.pluck(:date).to_set
  end

  def done?(date)
    @checked.include?(date)
  end

  def scheduled_today?
    @habit.scheduled_on?(@today)
  end

  def done_today?
    done?(@today)
  end

  # --- Semana atual (domingo..sábado) ---

  def week_target
    @habit.effective_weekly_target
  end

  def done_this_week
    checks_between(week_start(@today), week_start(@today) + 6)
  end

  def week_met?
    week_target.positive? && done_this_week >= week_target
  end

  # --- Sequência (streak) ---
  # weekly_count → semanas consecutivas batendo a meta; weekly_days → dias
  # agendados consecutivos feitos.
  def current_streak
    @habit.weekly_count? ? weekly_streak : daily_streak
  end

  # --- Adesão / Força ---

  # % de adesão na janela dos últimos `days` dias (respeitando a criação).
  def adherence(days: 30)
    pct_done(days)
  end

  def strength_pct
    pct_done(STRENGTH_WINDOW)
  end

  # :new (sem histórico) | :strong | :medium | :weak
  def strength
    return :new unless enough_history?

    pct = strength_pct
    return :strong if pct >= STRONG_MIN
    return :medium if pct >= MEDIUM_MIN

    :weak
  end

  # Timeline para o mini-grid: [{date:, scheduled:, done:}, ...].
  def last_days(count = 7)
    timeline(count)
  end

  def timeline(count = 28)
    ((@today - (count - 1))..@today).map do |d|
      { date: d, scheduled: @habit.scheduled_on?(d), done: done?(d) }
    end
  end

  private

  def enough_history?
    @habit.created_at.to_date <= @today - MIN_HISTORY_DAYS
  end

  def pct_done(days)
    start = [@today - (days - 1), @habit.created_at.to_date].max

    if @habit.weekly_count?
      target = @habit.weekly_target.to_i
      return 100 if target <= 0

      total_days = (@today - start).to_i + 1
      opportunities = target * total_days / 7.0
      return 100 if opportunities < 1

      done = @checked.count { |d| d >= start && d <= @today }
      (done * 100.0 / opportunities).round.clamp(0, 100)
    else
      scheduled = (start..@today).select { |d| @habit.scheduled_on?(d) }
      return 100 if scheduled.empty?

      (scheduled.count { |d| done?(d) } * 100.0 / scheduled.size).round.clamp(0, 100)
    end
  end

  def week_start(date)
    date - date.wday # alinha no domingo (igual ao ContributionGraph)
  end

  def checks_between(from, to)
    @checked.count { |d| d >= from && d <= to }
  end

  # Semanas consecutivas (terminando na semana atual) que bateram a meta. A
  # semana atual em andamento não quebra a sequência se ainda não bateu.
  def weekly_streak
    target = @habit.effective_weekly_target
    return 0 if target <= 0

    streak = 0
    week = week_start(@today)
    streak += 1 if checks_between(week, week + 6) >= target

    loop do
      week -= 7
      break if checks_between(week, week + 6) < target

      streak += 1
    end
    streak
  end

  # Dias agendados consecutivos (terminando hoje) marcados como feitos. Se hoje
  # ainda não foi feito, não quebra a sequência: conta a partir de ontem.
  def daily_streak
    streak = 0
    date = @today
    date -= 1 if @habit.scheduled_on?(date) && !done?(date)

    3650.times do
      if @habit.scheduled_on?(date)
        break unless done?(date)

        streak += 1
      end
      date -= 1
    end
    streak
  end
end
