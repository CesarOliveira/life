module Api
  # GET /api/shortcut — atalho de Tempo de tela (.shortcut) NÃO ASSINADO, já com
  # o token da conta embutido. Autenticado por Bearer (só o app tem o token), por
  # isso é "apenas do app". Exige "Permitir Atalhos Não Confiáveis" no iPhone.
  class ShortcutController < BaseController
    def show
      builder = HealthShortcutBuilder.new(
        endpoint: api_health_raw_url,
        token: current_account.api_token
      )
      response.set_header("Cache-Control", "no-store")
      send_data builder.plist,
                filename: builder.filename,
                type: "application/octet-stream",
                disposition: "attachment"
    end
  end
end
