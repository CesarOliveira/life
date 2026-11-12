# Endpoint do servidor MCP (transporte "Streamable HTTP", sem sessão):
#   POST /mcp/<token>        -> JSON-RPC 2.0 (mensagem única ou lote)
#   POST /mcp + Authorization: Bearer <token>
# O token é o Account#mcp_token (só leitura, opcional). GET/DELETE respondem 405:
# o servidor não abre stream nem guarda sessão.
class McpController < ActionController::API
  RATE_LIMIT = 120 # requisições por minuto por conta
  MAX_BODY_BYTES = 200_000

  before_action :authenticate!
  before_action :throttle!

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

  def authenticate!
    token = params[:token].presence || request.headers["Authorization"].to_s[/\ABearer\s+(.+)\z/i, 1]
    @account = Account.find_by(mcp_token: token) if token.present? && token.length >= 20
    head :unauthorized unless @account
  end

  def throttle!
    return if Rails.env.test?

    count = Rails.cache.increment("mcp_rl:#{@account.id}", 1, expires_in: 1.minute)
    head :too_many_requests if count.to_i > RATE_LIMIT
  end
end
