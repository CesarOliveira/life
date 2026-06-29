module Api
  # Base das rotas de API: autenticação por token pessoal (Account#api_token),
  # sem Devise/sessão/CSRF. Token SOMENTE via header "Authorization: Bearer <token>".
  class BaseController < ActionController::API
    MAX_BODY_BYTES = 2_000_000
    RATE_LIMIT = 120 # requisições por minuto por IP
    DATE_WINDOW_PAST = 90 # dias aceitos no passado na ingestão

    before_action :reject_large_body
    before_action :throttle!
    before_action :authenticate_account!

    private

    def authenticate_account!
      @current_account = Account.find_by(api_token: bearer_token) if bearer_token.present?
      return if @current_account

      render json: { error: "unauthorized" }, status: :unauthorized
    end

    def bearer_token
      request.headers["Authorization"].to_s[/\ABearer\s+(.+)\z/i, 1]
    end

    def reject_large_body
      return if request.content_length.to_i <= MAX_BODY_BYTES

      render json: { error: "payload_too_large" }, status: :payload_too_large
    end

    # Throttle simples por IP via cache (Redis). Desligado em teste para não
    # acumular contador entre execuções da suíte.
    def throttle!
      return if Rails.env.test?

      count = Rails.cache.increment("api_rl:#{request.remote_ip}", 1, expires_in: 1.minute)
      render json: { error: "rate_limited" }, status: :too_many_requests if count.to_i > RATE_LIMIT
    end

    attr_reader :current_account

    # --- Helpers de ingestão (compartilhados pelas rotas de API) ---

    def parsed_body
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
    end

    # Data padrão do lote: `date` explícito tem prioridade; senão resolve
    # `period` ("today"/"yesterday"/"hoje"/"ontem") no fuso do app.
    def default_date_from(data)
      return data["date"] if data["date"].to_s.strip.present?

      case data["period"].to_s.strip.downcase
      when "yesterday", "ontem" then (Date.current - 1).iso8601
      when "today", "hoje" then Date.current.iso8601
      end
    end

    def parse_date(raw)
      Date.iso8601(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def date_in_window?(date)
      today = Date.current
      date >= (today - DATE_WINDOW_PAST) && date <= (today + 1)
    end

    def render_error(code, **extra)
      render json: { error: code, **extra }, status: :unprocessable_entity
    end
  end
end
