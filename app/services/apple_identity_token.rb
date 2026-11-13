require "net/http"

# Valida o token de identidade do "Iniciar sessão com a Apple" enviado pelo app.
# O token é um JWT assinado pela Apple (RS256). Conferimos a assinatura com as
# chaves públicas dela, o emissor, o destinatário (o identificador do nosso app)
# e a validade. Devolve as claims ou nil.
class AppleIdentityToken
  ISSUER = "https://appleid.apple.com".freeze
  KEYS_URL = "https://appleid.apple.com/auth/keys".freeze
  CACHE_KEY = "apple_jwks".freeze

  # Identificadores do app aceitos como destinatário (bundle id). Separados por vírgula.
  def self.audiences
    ENV.fetch("APPLE_BUNDLE_IDS", "online.cesaroliveira.lifeApp").split(",").map(&:strip).reject(&:blank?)
  end

  def self.verify(token)
    new(token).verify
  end

  def initialize(token)
    @token = token.to_s
  end

  def verify
    return nil if @token.blank? || @token.length > 5000

    decode(self.class.jwks) || decode(self.class.jwks(refresh: true)) # a Apple troca as chaves de tempos em tempos
  end

  def self.jwks(refresh: false)
    Rails.cache.delete(CACHE_KEY) if refresh
    Rails.cache.fetch(CACHE_KEY, expires_in: 12.hours) { fetch_jwks }
  end

  def self.fetch_jwks
    uri = URI(KEYS_URL)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) { |http| http.get(uri.request_uri) }
    response.is_a?(Net::HTTPOK) ? JSON.parse(response.body) : { "keys" => [] }
  rescue StandardError => e
    Rails.logger.warn("Apple JWKS: #{e.class}")
    { "keys" => [] }
  end

  private

  def decode(jwks)
    keys = Array(jwks && jwks["keys"])
    return nil if keys.empty?

    claims, = JWT.decode(@token, nil, true,
                         algorithms: ["RS256"], jwks: { keys: keys },
                         iss: ISSUER, verify_iss: true,
                         aud: self.class.audiences, verify_aud: true)
    claims["sub"].present? ? claims : nil
  rescue JWT::DecodeError
    nil
  end
end
