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

    # Registra a requisição de ingestão (diagnóstico). Chamado via after_action
    # nas rotas de ingestão; @ingestion_result é o resumo montado na action.
    def record_ingestion(endpoint)
      raw = request.raw_post.to_s.dup.force_encoding("UTF-8").scrub
      IngestionLog.create!(
        account: current_account,
        endpoint: endpoint,
        client_version: params[:client_version].to_s.first(40).presence,
        byte_size: raw.bytesize,
        status: response.status,
        query: request.query_parameters.slice("key", "period", "device", "client_version"),
        result: @ingestion_result || {},
        raw_body: raw.first(IngestionLog::RAW_LIMIT),
        ip: request.remote_ip
      )
    rescue StandardError => e
      Rails.logger.error("IngestionLog falhou: #{e.class}: #{e.message}")
    end

    # Normaliza um valor que deveria ser uma lista de hashes: aceita Array, string
    # JSON (array ou hash único) ou hashes separados por quebra de linha — que é
    # como o app Atalhos às vezes serializa listas. Retorna Array ou nil.
    def coerce_list(value)
      return value if value.is_a?(Array)
      return nil unless value.is_a?(String)

      parsed = safe_json(value)
      return parsed if parsed.is_a?(Array)
      return [parsed] if parsed.is_a?(Hash)

      rows = value.split(/\r?\n/).filter_map { |line| safe_json(line) }
      rows.select { |row| row.is_a?(Hash) }.presence
    end

    def safe_json(str)
      return nil if str.to_s.strip.empty?

      JSON.parse(str)
    rescue JSON::ParserError
      nil
    end
  end
end
