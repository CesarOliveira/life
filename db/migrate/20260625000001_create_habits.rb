class CreateHabits < ActiveRecord::Migration[8.1]
  def change
    create_table :habits do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :color, null: false, default: "#6366f1"
      t.integer :weekdays, array: true, null: false, default: [0, 1, 2, 3, 4, 5, 6]
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :habits, [:account_id, :active]
  end
end
