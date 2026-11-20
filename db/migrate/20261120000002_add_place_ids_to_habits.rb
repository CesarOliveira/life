# Hábito automático "tempo em lugar": quais lugares somam (ex.: Academia).
class AddPlaceIdsToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :place_ids, :bigint, array: true, default: [], null: false
  end
end
