# Conectores: integrações que puxam dados automaticamente (GitHub etc.).
# O token OAuth fica criptografado (ActiveRecord Encryption).
class CreateConnectors < ActiveRecord::Migration[8.1]
  def change
    create_table :connectors do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false                      # github, ...
      t.string :status, null: false, default: "active" # active | paused | error
      t.jsonb :settings, null: false, default: {}      # login, backfill_years...
      t.text :access_token                             # criptografado
      t.datetime :last_synced_at
      t.string :last_error
      t.integer :last_points, null: false, default: 0
      t.timestamps
      t.index [:account_id, :kind], unique: true
    end
  end
end
