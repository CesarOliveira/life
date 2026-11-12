# Tempo de tela em blocos de 15 minutos (slot 0 = 00:00–00:15 … 95 = 23:45–24:00,
# no fuso local do aparelho). Complementa app_usages (total do dia) para análises
# por horário, como o uso logo antes de dormir.
class CreateAppUsageSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :app_usage_slots do |t|
      t.references :account, null: false, foreign_key: true
      t.string :device, null: false, default: "iphone"
      t.date :date, null: false
      t.integer :slot, null: false, limit: 2
      t.string :bundle_id, null: false
      t.string :name
      t.integer :seconds, null: false, default: 0
      t.timestamps
    end
    add_index :app_usage_slots, [:account_id, :device, :date, :slot, :bundle_id], unique: true, name: "idx_app_usage_slots_unique"
    add_index :app_usage_slots, [:account_id, :date]
  end
end
