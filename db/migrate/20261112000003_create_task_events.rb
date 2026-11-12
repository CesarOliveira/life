# Histórico de cada tarefa: criação e movimentações entre colunas, com data.
# Guarda os NOMES das colunas (não ids) para o histórico sobreviver a colunas
# renomeadas ou excluídas e aceitar histórico importado.
class CreateTaskEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :task_events do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :kind, null: false            # created | moved
      t.string :from_column
      t.string :to_column
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :task_events, [:task_id, :occurred_at]
  end
end
