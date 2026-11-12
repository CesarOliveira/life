module Mcp
  # Ferramentas de leitura do servidor MCP. Cada uma devolve um Hash pequeno e
  # autoexplicativo (datas ISO, minutos, rótulos em português) — o modelo lê isso
  # como texto, então nomes claros valem mais que estrutura compacta.
  class Tools
    class InvalidArguments < StandardError; end

    MAX_SPAN = 366 # dias por consulta
    DEFAULT_METRICS = %w[sleep_minutes sleep_bedtime sleep_wake sleep_deep_minutes sleep_rem_minutes steps active_energy
                         exercise_minutes stand_hours resting_hr hrv spo2 respiratory_rate workout_minutes].freeze
    OVERVIEW_METRICS = %w[sleep_minutes steps exercise_minutes active_energy resting_hr hrv].freeze

    PERIOD = {
      from: { type: "string", description: "Primeiro dia (AAAA-MM-DD). Padrão: 'to' menos o período padrão da ferramenta." },
      to: { type: "string", description: "Último dia (AAAA-MM-DD). Padrão: hoje." }
    }.freeze

    DEFINITIONS = [
      { name: "get_overview", title: "Visão geral",
        description: "Resumo de tudo no período (padrão: últimos 7 dias): tempo de tela, saúde, treinos, tarefas, hábitos, " \
                     "peso e exames, mais as datas em que cada tipo de dado começa e termina. Use primeiro.",
        properties: PERIOD },
      { name: "get_daily_snapshot", title: "Um dia inteiro",
        description: "Tudo o que foi registrado em UM dia: tempo de tela por app, todas as métricas de saúde, treinos, " \
                     "tarefas criadas/movidas/concluídas e hábitos marcados. Bom para explicar um dia específico.",
        properties: { date: { type: "string", description: "Dia (AAAA-MM-DD). Padrão: ontem." } } },
      { name: "get_screen_time", title: "Tempo de tela",
        description: "Tempo de tela do iPhone: total por dia e ranking de apps no período (padrão: 30 dias). " \
                     "Com 'app', devolve a série diária só daquele app.",
        properties: PERIOD.merge(app: { type: "string", description: "Nome do app, como aparece no ranking (ex.: Instagram)." }) },
      { name: "list_health_metrics", title: "Métricas de saúde disponíveis",
        description: "Lista as métricas de saúde que têm dados: chave, nome, unidade, seção, primeiro e último dia. " \
                     "Use para descobrir as chaves aceitas por get_health_metrics.",
        properties: {} },
      { name: "get_health_metrics", title: "Métricas de saúde",
        description: "Valores diários de métricas de saúde (iPhone e Apple Watch) no período (padrão: 30 dias). " \
                     "Sem 'metrics', devolve as principais de sono, atividade e coração. Horários (sleep_bedtime, sleep_wake) " \
                     "vêm como HH:MM; durações, em minutos.",
        properties: PERIOD.merge(metrics: { type: "array", items: { type: "string" },
                                            description: "Chaves das métricas (ver list_health_metrics). Máximo 25." }) },
      { name: "get_workouts", title: "Treinos",
        description: "Treinos individuais no período (padrão: 30 dias): tipo, início, duração, distância, ritmo, energia e " \
                     "frequência cardíaca média e máxima.",
        properties: PERIOD },
      { name: "get_tasks", title: "Tarefas",
        description: "Tarefas dos quadros kanban. status=open (padrão) lista as pendentes por quadro e coluna; " \
                     "status=done lista as concluídas no período (padrão: 30 dias); status=all, ambas. " \
                     "Inclui descrição, prazo, comentários e histórico de movimentações.",
        properties: PERIOD.merge(status: { type: "string", enum: %w[open done all], description: "Padrão: open." },
                                 board: { type: "string", description: "Nome do quadro. Padrão: todos." }) },
      { name: "get_habits", title: "Hábitos",
        description: "Hábitos ativos e em quais dias do período cada um foi cumprido (padrão: 30 dias), com a taxa de dias cumpridos.",
        properties: PERIOD },
      { name: "get_body", title: "Peso e corpo",
        description: "Peso (kg), IMC e composição corporal no período (padrão: 180 dias).",
        properties: PERIOD },
      { name: "get_exams", title: "Exames de laboratório",
        description: "Resultados de exames no período (padrão: 5 anos): nome, valor, unidade, faixa de referência do laudo e " \
                     "se está fora da faixa. As faixas vêm do próprio laudo, não do Life.",
        properties: PERIOD.merge(only_out_of_range: { type: "boolean", description: "Só resultados fora da faixa de referência." }) }
    ].freeze

    def self.definitions
      DEFINITIONS.map do |tool|
        { name: tool[:name], title: tool[:title], description: tool[:description],
          inputSchema: { type: "object", properties: tool[:properties], additionalProperties: false },
          annotations: { readOnlyHint: true, openWorldHint: false } }
      end
    end

    def self.known?(name)
      DEFINITIONS.any? { |tool| tool[:name] == name }
    end

    def initialize(account, today: Date.current)
      @account = account
      @today = today
    end

    def call(name, args)
      I18n.with_locale(:"pt-BR") { public_send(name, args) }
    end

    # ---------------------------------------------------------------- ferramentas

    def get_overview(args)
      from, to = period(args, 7)
      {
        period: { from: from, to: to, today: @today, timezone: Time.zone.name },
        data_coverage: coverage,
        screen_time: screen_time_summary(from, to),
        health_daily_averages: health_averages(from, to),
        workouts: workouts_summary(from, to),
        tasks: tasks_summary(from, to),
        habits: habits_summary(from, to),
        body: { latest_weight: latest_weight },
        exams: exams_summary
      }
    end

    def get_daily_snapshot(args)
      date = parse_date(args["date"], "date") || (@today - 1)
      usages = @account.app_usages.where(date: date)
      events = TaskEvent.joins(:task).where(tasks: { account_id: @account.id }, occurred_at: date.all_day).includes(:task)
      {
        date: date, weekday: I18n.l(date, format: "%A"),
        screen_time: { total_minutes: minutes(usages.sum(:seconds)), apps: app_ranking(usages, 40) },
        health: @account.measurements.where(category: "health", measured_on: date).order(:key).map { |m| metric_row(m) },
        workouts: @account.workouts.where(date: date).order(:started_at).map { |w| workout_row(w) },
        tasks: {
          events: events.order(:occurred_at).map { |e| { time: e.occurred_at.strftime("%H:%M"), task: e.task.title, kind: e.kind, from: e.from_column, to: e.to_column }.compact },
          completed: @account.tasks.where(completed_at: date.all_day).pluck(:title)
        },
        habits_done: HabitCheck.joins(:habit).where(habits: { account_id: @account.id }, date: date).pluck("habits.name"),
        weight_kg: @account.weight_entries.find_by(date: date)&.weight_kg&.to_f
      }
    end

    def get_screen_time(args)
      from, to = period(args, 30)
      usages = @account.app_usages.where(date: from..to)
      app = args["app"].to_s.strip
      if app.present?
        rows = usages.where("lower(coalesce(name, bundle_id)) = ? OR lower(bundle_id) = ?", app.downcase, app.downcase)
        daily = rows.group(:date).sum(:seconds)
        return { period: { from: from, to: to }, app: app, total_minutes: minutes(daily.values.sum), days_used: daily.size,
                 daily_minutes: daily.sort.to_h { |date, seconds| [date, minutes(seconds)] } }
      end

      daily = usages.group(:date).sum(:seconds)
      { period: { from: from, to: to }, days_with_data: daily.size,
        average_minutes_per_day: daily.empty? ? nil : minutes(daily.values.sum / daily.size),
        daily_total_minutes: daily.sort.to_h { |date, seconds| [date, minutes(seconds)] },
        apps: app_ranking(usages, 30),
        notes: "Fonte: uso de apps do iPhone sincronizado pelo Mac. Não inclui sites nem apps usados pelo CarPlay; o dia mais recente pode estar incompleto." }
    end

    def list_health_metrics(_args)
      stats = @account.measurements.where(category: "health").group(:key).pluck(:key, Arel.sql("min(measured_on)"), Arel.sql("max(measured_on)"), Arel.sql("count(*)"))
      { metrics: stats.sort_by { |key, *| Measurement.catalog_position(key) }.map do |key, first, last, count|
        { key: key, name: Measurement.key_label(key), unit: unit_for(key), section: Measurement.section(key),
          first_day: first, last_day: last, days: count }
      end }
    end

    def get_health_metrics(args)
      from, to = period(args, 30)
      keys = Array(args["metrics"]).map(&:to_s).first(25).presence || DEFAULT_METRICS
      rows = @account.measurements.where(category: "health", key: keys, measured_on: from..to).order(:measured_on)
      grouped = rows.group_by(&:key)
      { period: { from: from, to: to },
        metrics: keys.filter_map do |key|
          list = grouped[key]
          next if list.blank?

          values = list.map { |m| m.value.to_f }
          entry = { key: key, name: Measurement.key_label(key), unit: unit_for(key), days: list.size,
                    daily: list.to_h { |m| [m.measured_on, value_for(key, m.value)] } }
          entry.merge!(average: value_for(key, values.sum / values.size), min: value_for(key, values.min), max: value_for(key, values.max)) unless Measurement::TIME_KEYS.include?(key)
          entry
        end,
        without_data: keys - grouped.keys }
    end

    def get_workouts(args)
      from, to = period(args, 30)
      list = @account.workouts.where(date: from..to).order(:started_at)
      { period: { from: from, to: to }, count: list.size, total_minutes: list.sum(&:duration_seconds) / 60,
        workouts: list.map { |w| workout_row(w) } }
    end

    def get_tasks(args)
      status = %w[open done all].include?(args["status"].to_s) ? args["status"].to_s : "open"
      from, to = period(args, 30)
      scope = @account.tasks.includes(:task_board, :task_column, :comments, :events)
      if args["board"].to_s.strip.present?
        board = @account.task_boards.find_by("lower(name) = ?", args["board"].to_s.strip.downcase)
        raise InvalidArguments, "Quadro não encontrado: #{args['board']}. Quadros: #{@account.task_boards.pluck(:name).join(', ')}" if board.nil?

        scope = scope.where(task_board: board)
      end

      result = { boards: @account.task_boards.ordered.map { |b| { name: b.name, columns: b.columns.map(&:name) } } }
      result[:open] = scope.where(completed_at: nil).order(:task_board_id, :task_column_id, :position).map { |t| task_row(t) } if status != "done"
      if status != "open"
        result[:done_period] = { from: from, to: to }
        result[:done] = scope.where(completed_at: from.beginning_of_day..to.end_of_day).order(:completed_at).map { |t| task_row(t) }
      end
      result
    end

    def get_habits(args)
      from, to = period(args, 30)
      days = (to - from).to_i + 1
      checks = HabitCheck.joins(:habit).where(habits: { account_id: @account.id }, date: from..to).group_by(&:habit_id)
      { period: { from: from, to: to, days: days },
        habits: @account.habits.where(active: true).order(:position).map do |habit|
          dates = (checks[habit.id] || []).map(&:date).sort
          { name: habit.name, description: habit.description.presence, automatic: habit.auto, frequency: habit.frequency,
            days_done: dates.size, percent_of_days: (dates.size * 100.0 / days).round, done_on: dates }.compact
        end }
    end

    def get_body(args)
      from, to = period(args, 180)
      weights = @account.weight_entries.where(date: from..to).order(:date)
      body = @account.measurements.where(category: "health", key: %w[body_fat lean_mass body_bmi], measured_on: from..to).order(:measured_on)
      { period: { from: from, to: to }, height_cm: @account.height_cm,
        weight_kg: weights.to_h { |w| [w.date, w.weight_kg.to_f] },
        bmi_latest: weights.last&.bmi,
        composition: body.group_by(&:key).to_h { |key, list| [key, { name: Measurement.key_label(key), unit: unit_for(key), daily: list.to_h { |m| [m.measured_on, m.value.to_f] } }] } }
    end

    def get_exams(args)
      from, to = period(args, 5 * 365, max_span: 20 * 366)
      results = @account.exam_results.includes(exam_type: :exam_group).where(measured_on: from..to).order(:measured_on).to_a
      results = results.select(&:out_of_range?) if args["only_out_of_range"] == true
      { period: { from: from, to: to }, count: results.size,
        results: results.map do |r|
          { date: r.measured_on, exam: r.exam_type.name, group: r.exam_type.exam_group&.name, value: r.value.to_f, unit: r.unit,
            reference_low: r.ref_low&.to_f, reference_high: r.ref_high&.to_f,
            out_of_range: r.reference? ? r.out_of_range? : nil }.compact
        end,
        notes: "Faixas de referência extraídas do laudo de cada exame. Não substitui avaliação médica." }
    end

    private

    # ---------------------------------------------------------------- argumentos

    def period(args, default_days, max_span: MAX_SPAN)
      to = parse_date(args["to"], "to") || @today
      from = parse_date(args["from"], "from") || (to - (default_days - 1))
      raise InvalidArguments, "'from' (#{from}) deve ser anterior ou igual a 'to' (#{to})." if from > to
      raise InvalidArguments, "Período longo demais: no máximo #{max_span} dias por consulta." if (to - from).to_i >= max_span

      [from, to]
    end

    def parse_date(raw, name)
      return nil if raw.blank?

      Date.iso8601(raw.to_s)
    rescue ArgumentError
      raise InvalidArguments, "Data inválida em '#{name}': #{raw}. Use AAAA-MM-DD."
    end

    # ---------------------------------------------------------------- formatação

    def minutes(seconds)
      (seconds.to_f / 60).round
    end

    def unit_for(key)
      return "HH:MM" if Measurement::TIME_KEYS.include?(key)
      return "min" if Measurement::DURATION_KEYS.include?(key)

      Measurement.meta(key)[:unit]
    end

    def value_for(key, value)
      return format("%02d:%02d", value.to_i / 60, value.to_i % 60) if Measurement::TIME_KEYS.include?(key)

      number = value.to_f.round(2)
      number == number.to_i ? number.to_i : number
    end

    def metric_row(measurement)
      { key: measurement.key, name: measurement.label, value: value_for(measurement.key, measurement.value), unit: unit_for(measurement.key) }
    end

    def workout_row(workout)
      { date: workout.date, start: workout.started_at.strftime("%H:%M"), activity: workout.activity_label,
        minutes: workout.duration_seconds / 60, distance_km: workout.distance_km&.to_f, pace: workout.pace_label,
        energy_kcal: workout.energy_kcal&.round, avg_hr: workout.avg_hr&.round, max_hr: workout.max_hr&.round,
        source: workout.source }.compact
    end

    def task_row(task)
      { number: task.number, title: task.title, board: task.task_board.name, column: task.task_column.name,
        description: task.description.to_s.truncate(1500).presence, due_on: task.due_on, overdue: task.overdue? || nil,
        created_on: task.created_at.to_date, completed_on: task.completed_at&.to_date,
        days_open: ((task.completed_at || Time.current).to_date - task.created_at.to_date).to_i,
        comments: task.comments.map { |c| { date: c.created_at.to_date, text: c.body.truncate(800) } }.presence,
        history: task.events.map { |e| { date: e.occurred_at.to_date, kind: e.kind, from: e.from_column, to: e.to_column }.compact }.presence }.compact
    end

    def app_ranking(usages, limit)
      names = usages.where.not(name: nil).group(:bundle_id).maximum(:name)
      days = usages.group(:bundle_id).distinct.count(:date)
      usages.group(:bundle_id).sum(:seconds).sort_by { |_, seconds| -seconds }.first(limit).map do |bundle, seconds|
        { app: names[bundle].presence || bundle, minutes: minutes(seconds), days_used: days[bundle] }
      end
    end

    # ---------------------------------------------------------------- resumos

    def coverage
      range = ->(scope, column) { (first = scope.minimum(column)) && { first_day: first.to_date, last_day: scope.maximum(column).to_date } }
      { screen_time: range.call(@account.app_usages, :date),
        health: range.call(@account.measurements.where(category: "health"), :measured_on),
        workouts: range.call(@account.workouts, :date),
        tasks: range.call(@account.tasks, :created_at),
        weight: range.call(@account.weight_entries, :date),
        exams: range.call(@account.exam_results, :measured_on) }.compact
    end

    def screen_time_summary(from, to)
      usages = @account.app_usages.where(date: from..to)
      daily = usages.group(:date).sum(:seconds)
      return nil if daily.empty?

      { days_with_data: daily.size, average_minutes_per_day: minutes(daily.values.sum / daily.size),
        highest_day: daily.max_by { |_, s| s }.then { |date, s| { date: date, minutes: minutes(s) } },
        top_apps: app_ranking(usages, 5) }
    end

    def health_averages(from, to)
      rows = @account.measurements.where(category: "health", key: OVERVIEW_METRICS, measured_on: from..to).group(:key).average(:value)
      OVERVIEW_METRICS.filter_map do |key|
        next unless rows[key]

        { key: key, name: Measurement.key_label(key), average: value_for(key, rows[key]), unit: unit_for(key) }
      end
    end

    def workouts_summary(from, to)
      list = @account.workouts.where(date: from..to)
      { count: list.count, total_minutes: list.sum(:duration_seconds) / 60, by_activity: list.group(:activity).count }
    end

    def tasks_summary(from, to)
      open = @account.tasks.where(completed_at: nil)
      { open: open.count,
        open_by_column: open.joins(:task_board, :task_column).group("task_boards.name", "task_columns.name").count.map { |(board, column), n| { board: board, column: column, count: n } },
        overdue: open.where(due_on: ...@today).count,
        created_in_period: @account.tasks.where(created_at: from.beginning_of_day..to.end_of_day).count,
        completed_in_period: @account.tasks.where(completed_at: from.beginning_of_day..to.end_of_day).count }
    end

    def habits_summary(from, to)
      active = @account.habits.where(active: true)
      return nil if active.none?

      checks = HabitCheck.joins(:habit).where(habits: { account_id: @account.id, active: true }, date: from..to).count
      { active_habits: active.count, checks_in_period: checks }
    end

    def latest_weight
      entry = @account.weight_entries.recent_first.first
      entry && { date: entry.date, kg: entry.weight_kg.to_f, bmi: entry.bmi }.compact
    end

    def exams_summary
      latest = @account.exam_results.maximum(:measured_on)
      return nil if latest.nil?

      on_latest = @account.exam_results.where(measured_on: latest).to_a
      { total_results: @account.exam_results.count, latest_date: latest, results_on_latest_date: on_latest.size,
        out_of_range_on_latest_date: on_latest.count(&:out_of_range?) }
    end
  end
end
