# Move uma tarefa para uma coluna e posição (0 = topo), renumera a coluna de
# destino e marca/desmarca a conclusão conforme a coluna ser "concluído".
class TaskMover
  def initialize(task)
    @task = task
  end

  def call(column:, position: nil, user: nil)
    return false unless column.task_board.account_id == @task.account_id

    Task.transaction do
      source = @task.task_column
      siblings = column.tasks.where.not(id: @task.id).to_a
      index = position.nil? ? siblings.size : position.to_i.clamp(0, siblings.size)
      siblings.insert(index, @task)

      @task.update!(task_column: column, task_board: column.task_board, completed_at: completed_at_for(column))
      if source && source.id != column.id
        @task.events.create!(kind: "moved", from_column: source.name, to_column: column.name, user: user, occurred_at: Time.current)
      end
      renumber(siblings)
      renumber(source.tasks.reload.to_a) if source && source.id != column.id
    end
    true
  end

  private

  def renumber(tasks)
    tasks.each_with_index { |task, i| task.update_column(:position, i + 1) if task.position != i + 1 }
  end

  def completed_at_for(column)
    return nil unless column.done

    @task.completed_at || Time.current
  end
end
