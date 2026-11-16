# Página de Configuração do Tempo de tela: token pessoal, situação do envio e as
# duas formas de enviar o uso do iPhone: Life para Mac (/api/usage, recomendado)
# ou o Atalho do iPhone (/api/usage_raw). A Saúde vem pelo app nativo.
class SetupController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token
    @last_ingestion = IngestionLog.where(account: current_account, endpoint: %w[usage usage_raw]).recent_first.first
    @last_data_on = current_account.app_usages.maximum(:date)
    @github_connector = current_account.connectors.find_by(kind: "github")
    @mcp_url = mcp_url
    @mcp_token = current_account.mcp_token.presence
    @oauth_grants = current_account.oauth_grants.active.includes(:oauth_client).order(created_at: :desc)
  end

  # Liga (ou troca) o acesso de assistentes de IA: gera um token MCP novo.
  def enable_mcp
    current_account.enable_mcp!
    redirect_to setup_path(anchor: "mcp"), notice: t("flash.mcp.enabled")
  end

  def disable_mcp
    current_account.disable_mcp!
    redirect_to setup_path(anchor: "mcp"), notice: t("flash.mcp.disabled")
  end
end
