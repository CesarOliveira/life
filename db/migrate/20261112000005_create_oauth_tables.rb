# OAuth 2.1 para o servidor MCP: assistentes de IA entram com a conta do usuário
# em vez de copiar um token.
# - oauth_clients: aplicativos que pedem acesso (cadastro automático — DCR — ou
#   identidade publicada numa URL — CIMD).
# - oauth_grants: uma autorização dada por um usuário a um cliente. Guarda só os
#   HASHES do código, do access token e do refresh token.
class CreateOauthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id, null: false      # aleatório (DCR) ou a própria URL (CIMD)
      t.string :kind, null: false, default: "dcr"
      t.string :name
      t.string :redirect_uris, array: true, null: false, default: []
      t.datetime :metadata_fetched_at       # CIMD: quando o documento foi lido
      t.timestamps
    end
    add_index :oauth_clients, :client_id, unique: true

    create_table :oauth_grants do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :oauth_client, null: false, foreign_key: true
      t.string :scope, null: false, default: "life:read"
      t.string :redirect_uri, null: false
      t.string :resource
      t.string :code_digest
      t.string :code_challenge
      t.datetime :code_expires_at
      t.string :access_token_digest
      t.datetime :access_expires_at
      t.string :refresh_token_digest
      t.datetime :refresh_expires_at
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :oauth_grants, :code_digest, unique: true
    add_index :oauth_grants, :access_token_digest, unique: true
    add_index :oauth_grants, :refresh_token_digest, unique: true
  end
end
