class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    # Meta de alvo: progresso de uma métrica (peso, exame…) de start_value até
    # target_value. Não é recorrente — é um alvo (ex.: "chegar a 80 kg").
    create_table :goals do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :metric_key, null: false
      t.decimal :start_value, precision: 12, scale: 3
      t.decimal :target_value, precision: 12, scale: 3, null: false
      t.date :deadline
      t.date :achieved_on
      t.timestamps
    end
  end
end
