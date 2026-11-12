module Api
  # POST /api/tasks — cria/atualiza tarefas por token (importação e integrações).
  # Corpo JSON:
  #   { "tasks": [ { "external_id": "trello:abc", "board": "Tarefas Diárias",
  #       "column": "A fazer", "title": "…", "description": "…", "due_on": "2026-11-20",
  #       "created_at": "…", "completed_at": "…",
  #       "comments": [ { "body": "…", "created_at": "…" } ] } ] }
  # Quadro e coluna são achados pelo nome e criados se não existirem. Com
  # `external_id`, reenviar atualiza a tarefa em vez de duplicar (os comentários
  # só são gravados na criação).
  class TasksController < BaseController
    after_action(only: :create) { record_ingestion("tasks") }

    MAX_ENTRIES = 200

    def create
      data = parsed_body
      list = data.is_a?(Hash) ? coerce_list(data["tasks"]) : nil
      return render_error("invalid_payload") unless list.is_a?(Array)
      return render_error("too_many_entries", max: MAX_ENTRIES) if list.size > MAX_ENTRIES

      created = updated = skipped = 0
      list.each do |entry|
        case upsert(entry)
        when :created then created += 1
        when :updated then updated += 1
        else skipped += 1
        end
      end

      @ingestion_result = { created: created, updated: updated, skipped: skipped }
      render json: { ok: true, created: created, updated: updated, skipped: skipped }
    end

    private

    def upsert(entry)
      return nil unless entry.is_a?(Hash) && entry["title"].to_s.strip.present?

      board = find_board(entry["board"])
      column = find_column(board, entry["column"])
      external_id = entry["external_id"].to_s.strip.first(120).presence
      task = external_id && current_account.tasks.find_by(external_id: external_id)
      is_new = task.nil?
      task ||= current_account.tasks.new(external_id: external_id)

      task.assign_attributes(task_board: board, task_column: column, title: entry["title"].to_s.strip.first(200),
                             description: entry["description"].to_s.presence, due_on: parse_date(entry["due_on"]),
                             completed_at: completed_at(entry, column, task))
      task.created_at = parse_time(entry["created_at"]) || Time.current if is_new
      return nil unless task.save

      add_comments(task, entry["comments"]) if is_new
      is_new ? :created : :updated
    end

    def find_board(name)
      name = name.to_s.strip.first(80).presence || I18n.t("tasks.title")
      current_account.task_boards.find_by(name: name) ||
        TaskBoard.create_with_columns!(account: current_account, name: name)
    end

    def find_column(board, name)
      name = name.to_s.strip.first(40)
      return board.columns.first if name.blank?

      board.columns.find { |c| c.name.casecmp?(name) } ||
        board.columns.create!(name: name, position: board.columns.maximum(:position).to_i + 1)
    end

    def completed_at(entry, column, task)
      explicit = parse_time(entry["completed_at"])
      return explicit if explicit
      return nil unless column.done

      task.completed_at || Time.current
    end

    def add_comments(task, comments)
      Array(comments).first(100).each do |comment|
        body = comment.is_a?(Hash) ? comment["body"].to_s.strip : ""
        next if body.blank?

        task.comments.create(body: body.first(5000), created_at: parse_time(comment["created_at"]) || Time.current)
      end
    end

    def parse_time(raw)
      raw.present? ? Time.zone.parse(raw.to_s) : nil
    rescue ArgumentError
      nil
    end
  end
end
