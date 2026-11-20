module Places
  # Reavalia só os hábitos automáticos de lugar, nos dias tocados (até 90 dias atrás),
  # depois de chegarem visitas ou de um lugar mudar.
  class HabitRefresh
    WINDOW = 90

    def self.call(account, dates = nil)
      habits = account.habits.automatic.where(metric_key: "place_minutes").to_a
      return if habits.empty?

      floor = Date.current - WINDOW
      dates = Array(dates).compact.uniq.select { |d| d >= floor }
      evaluator = HabitRuleEvaluator.new(account)
      habits.each { |habit| dates.each { |d| evaluator.backfill(habit, from: d, to: d) } }
    end

    # Depois de criar/alterar um lugar: refaz a janela inteira.
    def self.full(account)
      call(account, ((Date.current - WINDOW)..Date.current).to_a)
    end
  end
end
