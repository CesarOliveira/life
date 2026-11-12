module Mcp
  # Ferramentas do servidor MCP: leitura sempre, escrita só com life:write.
  # Cada uma devolve um Hash pequeno e
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
      { name: "get_screen_time_by_hour", title: "Tempo de tela por horário",
        description: "Em que horas do dia o iPhone é usado (padrão: últimos 14 dias, máximo 62): média de minutos por hora, " \
                     "e por dia o total, o primeiro e o último uso e os minutos por hora. Inclui 'before_bed': para cada noite com " \
                     "hora de dormir registrada, os minutos de tela nos 60 minutos antes de dormir e em quais apps, ao lado da " \
                     "duração do sono — use para testar se tela antes de dormir se relaciona com o sono. Com 'app', restringe a um app.",
        properties: PERIOD.merge(app: { type: "string", description: "Nome do app (ex.: Instagram)." }) },
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

    TASK_REF = { number: { type: "integer", description: "Número da tarefa (o #N mostrado em get_tasks)." } }.freeze

    # Ferramentas de ESCRITA: só existem com a permissão life:write. Nenhuma apaga dados.
    WRITE_DEFINITIONS = [
      { name: "create_task", title: "Criar tarefa",
        description: "Cria uma tarefa. Sem 'board', usa o primeiro quadro; sem 'column', a primeira coluna. " \
                     "Use get_tasks antes para ver quadros e colunas existentes.",
        required: ["title"],
        properties: { title: { type: "string" }, description: { type: "string" },
                      board: { type: "string", description: "Nome do quadro." }, column: { type: "string", description: "Nome da coluna." },
                      due_on: { type: "string", description: "Prazo (AAAA-MM-DD)." } } },
      { name: "update_task", title: "Editar tarefa",
        description: "Altera título, descrição ou prazo de uma tarefa. Só os campos enviados mudam; due_on vazio remove o prazo.",
        required: ["number"],
        properties: TASK_REF.merge(title: { type: "string" }, description: { type: "string" }, due_on: { type: "string", description: "AAAA-MM-DD ou vazio." }) },
      { name: "move_task", title: "Mover tarefa",
        description: "Move a tarefa para outra coluna (do mesmo quadro, ou de outro se 'board' for informado). " \
                     "Mover para a coluna de concluído marca a tarefa como concluída.",
        required: %w[number column],
        properties: TASK_REF.merge(column: { type: "string", description: "Nome da coluna de destino." }, board: { type: "string", description: "Nome do quadro de destino." }) },
      { name: "add_task_comment", title: "Comentar tarefa",
        description: "Adiciona um comentário a uma tarefa.",
        required: %w[number text], properties: TASK_REF.merge(text: { type: "string" }) },
      { name: "create_board", title: "Criar quadro",
        description: "Cria um quadro de tarefas. Sem 'columns', usa a sugestão padrão (A fazer, Em andamento, QA, Concluído). " \
                     "A última coluna é tratada como concluído.",
        required: ["name"],
        properties: { name: { type: "string" }, columns: { type: "array", items: { type: "string" }, description: "Nomes das colunas, na ordem. Máximo 12." } } },
      { name: "rename_board", title: "Renomear quadro",
        description: "Muda o nome de um quadro.",
        required: %w[board name], properties: { board: { type: "string", description: "Nome atual." }, name: { type: "string", description: "Nome novo." } } },
      { name: "add_column", title: "Criar coluna",
        description: "Adiciona uma coluna ao fim de um quadro. Use move_column para reposicionar.",
        required: %w[board name],
        properties: { board: { type: "string" }, name: { type: "string" },
                      color: { type: "string", enum: TaskColumn::COLORS, description: "Padrão: slate (cinza)." },
                      done: { type: "boolean", description: "true se tarefas nesta coluna contam como concluídas." } } },
      { name: "update_column", title: "Alterar coluna",
        description: "Renomeia, troca a cor ou muda se a coluna significa concluído. Só os campos enviados mudam.",
        required: %w[board column],
        properties: { board: { type: "string" }, column: { type: "string", description: "Nome atual da coluna." },
                      name: { type: "string", description: "Nome novo." }, color: { type: "string", enum: TaskColumn::COLORS }, done: { type: "boolean" } } },
      { name: "move_column", title: "Reordenar coluna",
        description: "Move uma coluna dentro do quadro para a posição informada (1 = primeira, à esquerda).",
        required: %w[board column position],
        properties: { board: { type: "string" }, column: { type: "string" }, position: { type: "integer", minimum: 1 } } },
      { name: "set_habit_done", title: "Marcar hábito",
        description: "Marca ou desmarca um hábito MANUAL num dia (padrão: hoje). Hábitos automáticos seguem a métrica e não podem ser marcados.",
        required: ["habit"],
        properties: { habit: { type: "string", description: "Nome do hábito, como em get_habits." },
                      date: { type: "string", description: "AAAA-MM-DD. Padrão: hoje." }, done: { type: "boolean", description: "Padrão: true." } } },
      { name: "log_weight", title: "Registrar peso",
        description: "Registra o peso (kg) de um dia (padrão: hoje). Regravar o mesmo dia substitui o valor.",
        required: ["kg"],
        properties: { kg: { type: "number" }, date: { type: "string", description: "AAAA-MM-DD. Padrão: hoje." } } }
    ].freeze

    def initialize(account, today: Date.current, write: false, user: nil)
      @account = account
      @today = today
      @write = write
      @user = user
    end

    def definitions
      read = DEFINITIONS.map { |tool| definition(tool, read_only: true) }
      @write ? read + WRITE_DEFINITIONS.map { |tool| definition(tool, read_only: false) } : read
    end

    def known?(name)
      DEFINITIONS.any? { |tool| tool[:name] == name } || (@write && WRITE_DEFINITIONS.any? { |tool| tool[:name] == name })
    end

    def call(name, args)
      I18n.with_locale(:"pt-BR") { public_send(name, args) }
    end

    # ---------------------------------------------------------------- escrita

    def create_task(args)
      title = args["title"].to_s.strip
      raise InvalidArguments, "Informe 'title'." if title.blank?

      board = find_board!(args["board"])
      column = find_column!(board, args["column"])
      task = board.tasks.create!(account: @account, task_column: column, creator: @user, title: title.first(200),
                                 description: args["description"].to_s.presence, due_on: parse_date(args["due_on"], "due_on"),
                                 completed_at: column.done ? Time.current : nil)
      { created: task_row(task.reload) }
    end

    def update_task(args)
      task = find_task!(args["number"])
      changes = {}
      changes[:title] = args["title"].to_s.strip.first(200) if args.key?("title") && args["title"].to_s.strip.present?
      changes[:description] = args["description"].to_s.presence if args.key?("description")
      changes[:due_on] = parse_date(args["due_on"], "due_on") if args.key?("due_on")
      raise InvalidArguments, "Nada para alterar: envie title, description ou due_on." if changes.empty?

      task.update!(changes)
      { updated: task_row(task.reload) }
    end

    def move_task(args)
      task = find_task!(args["number"])
      board = args["board"].to_s.strip.present? ? find_board!(args["board"]) : task.task_board
      column = find_column!(board, args["column"], required: true)
      TaskMover.new(task).call(column: column, user: @user)
      { moved: task_row(task.reload) }
    end

    def add_task_comment(args)
      task = find_task!(args["number"])
      text = args["text"].to_s.strip
      raise InvalidArguments, "Informe 'text'." if text.blank?

      task.comments.create!(body: text.first(5000), user: @user)
      { commented: task_row(task.reload) }
    end

    def create_board(args)
      name = args["name"].to_s.strip
      raise InvalidArguments, "Informe 'name'." if name.blank?
      raise InvalidArguments, "Já existe um quadro chamado #{name}." if @account.task_boards.any? { |b| b.name.casecmp?(name) }
      raise InvalidArguments, "Limite de 30 quadros por conta." if @account.task_boards.count >= 30

      board = TaskBoard.create_with_columns!(account: @account, name: name.first(80), column_names: args["columns"])
      { created: board_row(board) }
    end

    def rename_board(args)
      board = find_board!(args["board"].to_s.presence || raise(InvalidArguments, "Informe 'board'."))
      name = args["name"].to_s.strip
      raise InvalidArguments, "Informe 'name'." if name.blank?

      board.update!(name: name.first(80))
      { renamed: board_row(board) }
    end

    def add_column(args)
      board = find_board!(args["board"].to_s.presence || raise(InvalidArguments, "Informe 'board'."))
      name = args["name"].to_s.strip
      raise InvalidArguments, "Informe 'name'." if name.blank?
      raise InvalidArguments, "O quadro já tem uma coluna #{name}." if board.columns.any? { |c| c.name.casecmp?(name) }
      raise InvalidArguments, "Limite de 12 colunas por quadro." if board.columns.size >= 12

      board.columns.create!(name: name.first(40), color: column_color(args["color"]) || "slate", done: args["done"] == true,
                            position: board.columns.maximum(:position).to_i + 1)
      { board: board_row(board.reload) }
    end

    def update_column(args)
      board = find_board!(args["board"].to_s.presence || raise(InvalidArguments, "Informe 'board'."))
      column = find_column!(board, args["column"], required: true)
      changes = {}
      changes[:name] = args["name"].to_s.strip.first(40) if args["name"].to_s.strip.present?
      changes[:color] = column_color(args["color"]) if args.key?("color")
      changes[:done] = args["done"] == true if args.key?("done")
      raise InvalidArguments, "Nada para alterar: envie name, color ou done." if changes.compact.empty?

      column.update!(changes.compact)
      { board: board_row(board.reload) }
    end

    def move_column(args)
      board = find_board!(args["board"].to_s.presence || raise(InvalidArguments, "Informe 'board'."))
      column = find_column!(board, args["column"], required: true)
      columns = board.columns.to_a
      raise InvalidArguments, "'position' deve ficar entre 1 e #{columns.size}." unless args["position"].to_i.between?(1, columns.size)

      columns.delete(column)
      columns.insert(args["position"].to_i - 1, column)
      columns.each_with_index { |c, index| c.update_column(:position, index) }
      { board: board_row(board.reload) }
    end

    def set_habit_done(args)
      name = args["habit"].to_s.strip
      habit = @account.habits.where(active: true).find_by("lower(name) = ?", name.downcase)
      raise InvalidArguments, "Hábito não encontrado: #{name}. Hábitos: #{@account.habits.where(active: true).pluck(:name).join(', ')}" if habit.nil?
      raise InvalidArguments, "\"#{habit.name}\" é automático: a marcação vem da métrica e não pode ser alterada." if habit.auto?

      date = parse_date(args["date"], "date") || @today
      raise InvalidArguments, "Não é possível marcar um dia futuro." if date > @today

      done = args["done"] != false
      check = habit.habit_checks.find_by(date: date)
      done ? (check || habit.habit_checks.create!(date: date)) : check&.destroy
      { habit: habit.name, date: date, done: done }
    end

    def log_weight(args)
      kg = args["kg"].to_f
      raise InvalidArguments, "Peso inválido: informe 'kg' entre 20 e 400." unless kg.between?(20, 400)

      date = parse_date(args["date"], "date") || @today
      raise InvalidArguments, "Não é possível registrar um dia futuro." if date > @today

      entry = @account.weight_entries.find_or_initialize_by(date: date)
      entry.update!(weight_kg: kg.round(2))
      { date: date, weight_kg: entry.weight_kg.to_f, bmi: entry.bmi }.compact
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

    def get_screen_time_by_hour(args)
      from, to = period(args, 14, max_span: 62)
      hours = ScreenTimeHours.new(@account, from: from, to: to, app: args["app"].to_s.strip.presence)
      first = @account.app_usage_slots.minimum(:date)
      { period: { from: from, to: to }, app: args["app"].to_s.strip.presence, days_with_data: hours.days_with_data,
        hourly_data_available_since: first,
        average_minutes_by_hour: hours.average_minutes_by_hour.to_h { |hour, minutes| [format("%02dh", hour), minutes] },
        days: hours.days,
        before_bed: hours.before_bed,
        notes: "Resolução de 15 minutos, horário local. 'last_use_block' é o início do último bloco de 15 min com uso. " \
               "'before_bed' só aparece em noites com hora de dormir (Apple Watch) e tempo de tela sincronizado." }.compact
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
          { name: habit.name, description: habit.description.presence, automatic: habit.auto, rule: habit_rule(habit), frequency: habit.frequency,
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

    def definition(tool, read_only:)
      schema = { type: "object", properties: tool[:properties], additionalProperties: false }
      schema[:required] = tool[:required] if tool[:required]
      { name: tool[:name], title: tool[:title], description: tool[:description], inputSchema: schema,
        annotations: { readOnlyHint: read_only, destructiveHint: false, openWorldHint: false } }
    end

    # ---------------------------------------------------------------- busca (escrita)

    def board_row(board)
      { name: board.name, columns: board.columns.reload.map { |c| { name: c.name, color: c.color, done: c.done, tasks: c.tasks.size } } }
    end

    def column_color(value)
      return nil if value.blank?
      raise InvalidArguments, "Cor inválida: #{value}. Use uma de: #{TaskColumn::COLORS.join(', ')}." unless TaskColumn::COLORS.include?(value.to_s)

      value.to_s
    end

    def find_task!(number)
      task = @account.tasks.find_by(number: number.to_i)
      raise InvalidArguments, "Tarefa ##{number} não encontrada. Use get_tasks para ver os números." if task.nil?

      task
    end

    def find_board!(name)
      boards = @account.task_boards.ordered
      raise InvalidArguments, "A conta ainda não tem quadros de tarefas. Crie um com create_board." if boards.empty?
      return boards.first if name.to_s.strip.blank?

      boards.find { |b| b.name.casecmp?(name.to_s.strip) } ||
        raise(InvalidArguments, "Quadro não encontrado: #{name}. Quadros: #{boards.map(&:name).join(', ')}")
    end

    def find_column!(board, name, required: false)
      raise InvalidArguments, "Informe 'column'. Colunas de #{board.name}: #{board.columns.map(&:name).join(', ')}" if required && name.to_s.strip.blank?
      return board.columns.first if name.to_s.strip.blank?

      board.columns.find { |c| c.name.casecmp?(name.to_s.strip) } ||
        raise(InvalidArguments, "Coluna não encontrada: #{name}. Colunas de #{board.name}: #{board.columns.map(&:name).join(', ')}")
    end

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

    # Regra de um hábito automático: { metric:, operator:, threshold:, unit: }.
    def habit_rule(habit)
      return nil unless habit.auto?

      threshold = habit.time_of_day_metric? ? format("%02d:%02d", habit.threshold_value.to_i / 60, habit.threshold_value.to_i % 60) : habit.threshold_value.to_f
      { metric: I18n.t("habits.auto_metrics.#{habit.metric_key}", default: habit.metric_key), operator: habit.comparator == "lte" ? "no máximo" : "no mínimo",
        threshold: threshold, unit: habit.auto_metric[:unit], apps: habit.app_filtered? ? habit.app_bundle_ids : nil }.compact
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
