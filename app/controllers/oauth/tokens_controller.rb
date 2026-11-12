module Oauth
  # Endpoints de máquina do OAuth: cadastro automático de cliente (RFC 7591),
  # troca de código/refresh por tokens e revogação (RFC 7009).
  class TokensController < ActionController::API
    include Oauth::Cors

    REGISTER_LIMIT = 30 # cadastros por hora por IP

    before_action :no_store

    # POST /oauth/register
    def register
      return render_error("too_many_requests", "Muitos cadastros; tente mais tarde.", :too_many_requests) if register_throttled?

      data = parsed_json
      uris = Array(data["redirect_uris"]).map(&:to_s).first(20)
      client = OauthClient.new(client_id: SecureRandom.urlsafe_base64(24), kind: "dcr",
                               name: data["client_name"].to_s.first(120).presence, redirect_uris: uris)
      return render_error("invalid_redirect_uri", "redirect_uris ausente ou inválido.") unless client.save

      render status: :created, json: {
        client_id: client.client_id, client_id_issued_at: client.created_at.to_i, client_name: client.name,
        redirect_uris: client.redirect_uris, grant_types: %w[authorization_code refresh_token],
        response_types: ["code"], token_endpoint_auth_method: "none", scope: OauthGrant::SCOPES.join(" ")
      }.compact
    end

    # POST /oauth/token
    def create
      case params[:grant_type]
      when "authorization_code" then exchange_code
      when "refresh_token" then refresh
      else render_error("unsupported_grant_type", "Use authorization_code ou refresh_token.")
      end
    end

    # POST /oauth/revoke — sempre 200 (não revela se o token existia).
    def revoke
      digest = OauthGrant.digest(params[:token])
      grant = OauthGrant.find_by(refresh_token_digest: digest) || OauthGrant.find_by(access_token_digest: digest)
      grant&.revoke!
      head :ok
    end

    private

    def exchange_code
      grant = OauthGrant.find_by(code_digest: OauthGrant.digest(params[:code]), revoked_at: nil) if params[:code].present?
      return render_error("invalid_grant", "Código inválido ou já usado.") if grant.nil?

      # Código é de uso único: qualquer falha daqui em diante o inutiliza.
      valid = grant.code_expires_at&.future? &&
              grant.oauth_client.client_id == params[:client_id].to_s &&
              grant.redirect_uri == params[:redirect_uri].to_s &&
              grant.pkce_valid?(params[:code_verifier])
      unless valid
        grant.revoke!
        return render_error("invalid_grant", "Código expirado ou dados da troca não conferem.")
      end

      render json: grant.issue_tokens!
    end

    def refresh
      grant = OauthGrant.find_by(refresh_token_digest: OauthGrant.digest(params[:refresh_token]), revoked_at: nil) if params[:refresh_token].present?
      return render_error("invalid_grant", "Refresh token inválido.") if grant.nil? || grant.refresh_expires_at.nil? || grant.refresh_expires_at.past?
      return render_error("invalid_grant", "client_id não confere.") if params[:client_id].present? && grant.oauth_client.client_id != params[:client_id].to_s

      render json: grant.issue_tokens! # rotação: o refresh anterior deixa de valer
    end

    def parsed_json
      parsed = JSON.parse(request.raw_post)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def register_throttled?
      return false if Rails.env.test?

      Rails.cache.increment("oauth_reg:#{request.remote_ip}", 1, expires_in: 1.hour).to_i > REGISTER_LIMIT
    end

    def no_store
      response.set_header("Cache-Control", "no-store")
      response.set_header("Pragma", "no-cache")
    end

    def render_error(code, description, status = :bad_request)
      render json: { error: code, error_description: description }, status: status
    end
  end
end
