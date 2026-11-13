module Api
  module Mobile
    # Login do app sem navegador: e-mail e senha, ou "Iniciar sessão com a Apple".
    # Devolve o token da conta pessoal, o mesmo que o login com Google entrega.
    class SessionsController < ActionController::API
      IP_LIMIT = 30    # tentativas por IP a cada 10 min
      EMAIL_LIMIT = 8  # tentativas por e-mail a cada 10 min

      # POST /api/mobile/session  { email, password }
      def create
        email = params[:email].to_s.strip.downcase
        return render_error("too_many_attempts", :too_many_requests) if throttled?("ip:#{request.remote_ip}", IP_LIMIT) || throttled?("mail:#{email}", EMAIL_LIMIT)

        user = email.present? ? User.find_by(email: email) : nil
        return render_error("invalid_credentials", :unauthorized) unless user&.valid_password?(params[:password].to_s)

        render json: session_payload(user)
      end

      # POST /api/mobile/session/apple  { identity_token, name }
      def apple
        return render_error("too_many_attempts", :too_many_requests) if throttled?("ip:#{request.remote_ip}", IP_LIMIT)

        claims = AppleIdentityToken.verify(params[:identity_token])
        return render_error("invalid_token", :unauthorized) if claims.nil?

        user = User.from_apple(sub: claims["sub"], email: claims["email"], email_verified: claims["email_verified"].to_s == "true",
                               name: params[:name].to_s.strip.first(120).presence)
        return render_error("account_unavailable", :unprocessable_entity) unless user&.persisted?

        render json: session_payload(user)
      end

      private

      def session_payload(user)
        account = Account.ensure_personal_for(user, locale: I18n.locale)
        account.regenerate_api_token if account.api_token.blank?
        { token: account.api_token, user: { name: user.name, email: user.email } }
      end

      def throttled?(key, limit)
        return false if Rails.env.test?

        Rails.cache.increment("mobile_login:#{key}", 1, expires_in: 10.minutes).to_i > limit
      end

      def render_error(code, status)
        render json: { error: code }, status: status
      end
    end
  end
end
