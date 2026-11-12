module Oauth
  # CORS aberto para os endpoints OAuth/MCP usados por clientes rodando no
  # navegador. Seguro aqui: nenhum deles usa cookie — a credencial vai no corpo
  # ou no cabeçalho Authorization.
  module Cors
    extend ActiveSupport::Concern

    included do
      before_action :set_cors_headers
    end

    def preflight
      head :no_content
    end

    private

    def set_cors_headers
      response.set_header("Access-Control-Allow-Origin", "*")
      response.set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      response.set_header("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept, MCP-Protocol-Version, Mcp-Session-Id")
      response.set_header("Access-Control-Max-Age", "86400")
    end
  end
end
