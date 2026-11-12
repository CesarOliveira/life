# Treinos individuais vindos do app nativo (HealthKit: iPhone + Apple Watch).
# Um registro por treino, identificado pelo UUID do HealthKit (reenviar não
# duplica). Os totais por dia continuam em Measurement (workout_minutes etc.).
class CreateWorkouts < ActiveRecord::Migration[8.1]
  def change
    create_table :workouts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :uuid, null: false                # UUID do HKWorkout
      t.string :activity, null: false            # running, walking, strength...
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.date :date, null: false                  # dia local de início
      t.integer :duration_seconds, null: false, default: 0
      t.decimal :energy_kcal, precision: 8, scale: 1
      t.decimal :distance_m, precision: 10, scale: 1
      t.decimal :avg_hr, precision: 5, scale: 1
      t.decimal :max_hr, precision: 5, scale: 1
      t.string :source                           # app/aparelho que gravou
      t.timestamps
    end
    add_index :workouts, [:account_id, :uuid], unique: true, name: "idx_workouts_unique"
    add_index :workouts, [:account_id, :date]
  end
end
