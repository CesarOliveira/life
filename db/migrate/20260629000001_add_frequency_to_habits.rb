class AddFrequencyToHabits < ActiveRecord::Migration[8.1]
  def change
    # "weekly_days" (dias específicos da semana, comportamento atual) ou
    # "weekly_count" (Nx por semana, em qualquer dia). weekly_target só se aplica
    # ao segundo (ex.: Academia 3x/sem).
    add_column :habits, :frequency, :string, default: "weekly_days", null: false
    add_column :habits, :weekly_target, :integer
  end
end
