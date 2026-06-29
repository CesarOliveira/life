class AddAutoRuleToHabits < ActiveRecord::Migration[8.1]
  def change
    # Hábito automático: a marcação do dia é derivada de uma métrica (tela, sono,
    # passos…) por uma regra de limiar — ex.: "tela ≤ 3h", "sono ≥ 7h".
    add_column :habits, :auto, :boolean, default: false, null: false
    add_column :habits, :metric_key, :string
    add_column :habits, :comparator, :string         # "lte" (≤) ou "gte" (≥)
    add_column :habits, :threshold_value, :decimal, precision: 12, scale: 3
  end
end
