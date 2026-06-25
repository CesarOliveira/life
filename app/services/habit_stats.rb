# Estatísticas de um hábito (sequência/streak e adesão), calculadas a partir
# das datas marcadas. Carrega as datas uma vez para evitar N+1.
class HabitStats
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

  # Dias agendados consecutivos (terminando hoje) marcados como feitos.
  # Se hoje ainda não foi feito, não quebra a sequência: conta a partir de ontem.
  def current_streak
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

  # % de dias agendados feitos na janela dos últimos `days` dias (a partir da
  # criação do hábito, no mínimo).
  def adherence(days: 30)
    start = [@today - (days - 1), @habit.created_at.to_date].max
    scheduled = (start..@today).select { |d| @habit.scheduled_on?(d) }
    return 100 if scheduled.empty?

    (scheduled.count { |d| done?(d) } * 100.0 / scheduled.size).round
  end

  # Últimos `count` dias para o mini-grid: [{date:, scheduled:, done:}, ...].
  def last_days(count = 7)
    ((@today - (count - 1))..@today).map do |d|
      { date: d, scheduled: @habit.scheduled_on?(d), done: done?(d) }
    end
  end
end
