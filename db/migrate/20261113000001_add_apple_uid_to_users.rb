# Identificador estável do "Iniciar sessão com a Apple" (claim `sub` do token).
# Fica em coluna própria para a mesma pessoa poder entrar com Apple e com Google.
class AddAppleUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :apple_uid, :string
    add_index :users, :apple_uid, unique: true
  end
end
