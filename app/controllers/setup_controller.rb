# Página de Configuração: guia passo a passo (com checklist) para conectar o
# iPhone — instalar o atalho de Tempo de tela e criar a automação diária. A
# Saúde vem pelo app nativo.
class SetupController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token
    @endpoint = api_usage_url
    @health_version = HealthShortcutBuilder::VERSION
    # "Atualizar agora": dispara o atalho pelo nome fixo (WFWorkflowName).
    @shortcut_run_url = "shortcuts://run-shortcut?name=#{ERB::Util.url_encode(HealthShortcutBuilder::SHORTCUT_NAME)}"
    @github_connector = current_account.connectors.find_by(kind: "github")
  end
end
