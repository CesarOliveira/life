# Endpoint do servidor MCP (transporte "Streamable HTTP", sem sessão):
#   POST /mcp + Authorization: Bearer <access token OAuth>   (caminho principal)
#   POST /mcp + Authorization: Bearer <Account#mcp_token>    (token manual)
#   POST /mcp/<Account#mcp_token>                            (token no endereço)
# Tudo somente leitura. GET/DELETE respondem 405:
# o servidor não abre stream nem guarda sessão.
class McpController < ActionController::API
  include Oauth::Cors

  RATE_LIMIT = 120 # requisições por minuto por conta
  MAX_BODY_BYTES = 200_000

  before_action :authenticate!, except: :preflight
  before_action :throttle!, except: :preflight

  def create
    return head(:payload_too_large) if request.content_length.to_i > MAX_BODY_BYTES

    payload = JSON.parse(request.raw_post)
    server = Mcp::Server.new(@account)
    if payload.is_a?(Array)
      responses = payload.filter_map { |message| server.handle(message) }
      responses.empty? ? head(:accepted) : render(json: responses)
    else
      response_message = server.handle(payload)
      response_message ? render(json: response_message) : head(:accepted)
    end
  rescue JSON::ParserError
    render json: { jsonrpc: "2.0", id: nil, error: { code: -32_700, message: "Parse error" } }, status: :bad_request
  end

  def unsupported
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end

  private

  # Aceita, nesta ordem: access token OAuth (Bearer), token MCP no cabeçalho ou
  # token MCP no caminho. Sem credencial válida: 401 apontando para a descoberta
  # OAuth — é o que faz o cliente abrir a tela de login.
  def authenticate!
    bearer = request.headers["Authorization"].to_s[/\ABearer\s+(.+)\z/i, 1]
    @account = OauthGrant.account_for_access_token(bearer)
    legacy = params[:token].presence || bearer
    @account ||= Account.find_by(mcp_token: legacy) if legacy.present? && legacy.length >= 20
    return if @account

    metadata = "#{request.base_url}/.well-known/oauth-protected-resource"
    response.set_header("WWW-Authenticate", %(Bearer resource_metadata="#{metadata}", scope="#{OauthGrant::SCOPE}"))
    head :unauthorized
  end

  def throttle!
    return if Rails.env.test?

    count = Rails.cache.increment("mcp_rl:#{@account.id}", 1, expires_in: 1.minute)
    head :too_many_requests if count.to_i > RATE_LIMIT
  end
end
