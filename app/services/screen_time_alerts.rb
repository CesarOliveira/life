# Alerta intradiário de tempo de tela: para hábitos automáticos "no máximo X"
# (lte) de tela, detecta o momento em que o uso do dia CRUZA o limiar entre um
# sync e o seguinte, e monta a mensagem que o Atalho "Hoje" mostra como
# notificação local. Stateless: compara o valor antes/depois do upsert — alerta
# uma vez por cruzamento, sem repetir a cada novo sync já estourado.
class ScreenTimeAlerts
  def initialize(account)
    @account = account
  end

  # Horas de tela do dia por hábito (id => horas). Tirar ANTES do upsert.
  def snapshot(date)
    habits.to_h { |habit| [habit.id, hours(habit, date)] }
  end

  # Mensagens dos hábitos cujo limiar foi cruzado neste sync (antes ≤ limite < agora).
  def messages(date, previous: {})
    habits.filter_map do |habit|
      threshold = habit.threshold_value.to_f
      now = hours(habit, date)
      next unless now > threshold && previous.fetch(habit.id, 0.0) <= threshold

      "#{habit.name}: #{label(now)} hoje (limite #{label(threshold)})"
    end
  end

  private

  # Só hábitos ativos: notificação de hábito arquivado seria ruído.
  def habits
    @habits ||= @account.habits.active.automatic.select do |habit|
      habit.comparator == "lte" && habit.auto_metric[:source] == :app_usage
    end
  end

  def hours(habit, date)
    scope = @account.app_usages.where(date: date)
    scope = scope.where(bundle_id: Array(habit.app_bundle_ids)) if habit.app_filtered?
    scope.sum(:seconds) / 3600.0
  end

  # "2h 13m" / "45m" — mesmo formato das telas (humanize_duration), sem " 0m"
  # sobrando no limiar redondo ("2h 0m" -> "2h").
  def label(hours)
    ApplicationController.helpers.humanize_duration((hours * 3600).round).sub(/h 0m\z/, "h")
  end
end
