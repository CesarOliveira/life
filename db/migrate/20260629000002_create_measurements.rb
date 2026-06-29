class CreateMeasurements < ActiveRecord::Migration[8.1]
  def change
    # Tabela genérica de medições: cobre sinais de saúde (sono, passos…) e
    # exames (glicemia, colesterol… com faixa de referência). Uma medição por
    # (conta, chave, data) — idempotente na ingestão.
    create_table :measurements do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.decimal :value, precision: 12, scale: 3, null: false
      t.string :unit
      t.date :measured_on, null: false
      t.string :category, null: false, default: "health"
      t.decimal :ref_low, precision: 12, scale: 3
      t.decimal :ref_high, precision: 12, scale: 3
      t.string :source, null: false, default: "manual"
      t.timestamps
    end

    add_index :measurements, [:account_id, :key, :measured_on], unique: true, name: "idx_measurements_unique"
    add_index :measurements, [:account_id, :category]
  end
end
