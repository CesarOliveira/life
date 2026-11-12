# Página de Configuração do Tempo de tela: token pessoal e situação da coleta
# pelo Mac (script em tools/mac_screentime que lê o uso do iPhone sincronizado
# e envia para /api/usage). A Saúde vem pelo app nativo.
class SetupController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token
    @last_ingestion = IngestionLog.where(account: current_account, endpoint: "usage").recent_first.first
    @last_data_on = current_account.app_usages.maximum(:date)
    @github_connector = current_account.connectors.find_by(kind: "github")
    return if current_account.mcp_token.blank?

    @mcp_url = mcp_url(token: current_account.mcp_token)
    @mcp_masked = mcp_url(token: "#{current_account.mcp_token.first(6)}••••••••••")
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
