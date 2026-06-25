class AddBodyMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :height_cm, :integer

    create_table :weight_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :weight_kg, precision: 5, scale: 2, null: false

      t.timestamps
    end

    add_index :weight_entries, [:account_id, :date], unique: true
  end
end
