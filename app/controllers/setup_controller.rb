# Página de Configuração: guia passo a passo (com checklist) para conectar o
# iPhone — instalar os atalhos de Saúde e Tempo de tela e criar as automações
# diárias que disparam o envio sozinho.
class SetupController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token
    @endpoint = api_usage_url
    @health_version = HealthShortcutBuilder::VERSION
  end
end
