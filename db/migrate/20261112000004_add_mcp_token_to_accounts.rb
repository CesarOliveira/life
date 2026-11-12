# Token do servidor MCP (assistentes de IA lendo os dados da conta). Separado do
# api_token de ingestão: é só leitura, opcional (nil = acesso desligado) e pode
# ser revogado sem parar a coleta.
class AddMcpTokenToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :mcp_token, :string
    add_index :accounts, :mcp_token, unique: true
  end
end
