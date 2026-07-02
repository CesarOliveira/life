class CreateExamExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :exam_extractions do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :file_bytes, null: false, default: 0
      t.string :models_used, null: false, default: ""   # ex.: "claude-haiku-4-5" ou "haiku,sonnet"
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, null: false, default: 0
      t.integer :rows_count, null: false, default: 0
      t.string :status, null: false, default: "success" # success | failed
      t.string :error
      t.integer :duration_ms, null: false, default: 0

      t.timestamps
    end
    add_index :exam_extractions, :created_at
  end
end
