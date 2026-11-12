# Tarefas no estilo kanban: quadros personalizáveis por conta, cada um com suas
# colunas (nome, cor, ordem e se a coluna significa "concluído"), tarefas e
# comentários. `external_id` identifica tarefas vindas de fora (ex.: Trello, API)
# para a importação ser idempotente.
class CreateTaskBoards < ActiveRecord::Migration[8.1]
  def change
    create_table :task_boards do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :task_columns do |t|
      t.references :task_board, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "slate"
      t.integer :position, null: false, default: 0
      t.boolean :done, null: false, default: false
      t.timestamps
    end

    create_table :tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :task_board, null: false, foreign_key: true
      t.references :task_column, null: false, foreign_key: true
      t.references :creator, null: true, foreign_key: { to_table: :users }
      t.integer :number, null: false              # sequencial por conta (#12)
      t.string :title, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.date :due_on
      t.datetime :completed_at
      t.string :external_id
      t.timestamps
    end
    add_index :tasks, [:account_id, :number], unique: true
    add_index :tasks, [:account_id, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :tasks, [:task_column_id, :position]

    create_table :task_comments do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
