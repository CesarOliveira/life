class CreateHabitChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :habit_checks do |t|
      t.references :habit, null: false, foreign_key: true
      t.date :date, null: false

      t.timestamps
    end

    add_index :habit_checks, [:habit_id, :date], unique: true
  end
end
