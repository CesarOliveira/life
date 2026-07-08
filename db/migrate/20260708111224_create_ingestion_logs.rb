# Registro de TUDO que chega nas rotas de ingestão (/api/health_raw,
# /api/usage_raw) — corpo cru, query, resultado e status. Facilita depurar o
# atalho do iPhone sem adivinhação.
class CreateIngestionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ingestion_logs do |t|
      t.references :account, null: true, foreign_key: true
      t.string :endpoint, null: false          # health_raw | usage_raw
      t.string :client_version
      t.integer :byte_size, null: false, default: 0
      t.integer :status                         # HTTP status devolvido
      t.jsonb :query, null: false, default: {}  # key/period/device/client_version
      t.jsonb :result, null: false, default: {} # resumo do que foi parseado/gravado
      t.text :raw_body                          # corpo cru (limitado)
      t.string :ip
      t.datetime :created_at, null: false
      t.index :created_at
      t.index [:endpoint, :created_at]
    end
  end
end
