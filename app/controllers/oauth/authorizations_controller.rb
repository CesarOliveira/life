module Oauth
  # Tela de consentimento: o usuário (logado no Life) decide se o assistente pode
  # ler os dados da conta. Sem login, o Devise leva ao login e volta para cá.
  class AuthorizationsController < ApplicationController
    before_action :load_request, only: [:new, :create]

    # GET /oauth/authorize
    def new; end

    # POST /oauth/authorize
    def create
      return redirect_back_to_client(error: "access_denied") unless params[:decision] == "approve"

      grant = current_account.oauth_grants.create!(
        user: current_user, oauth_client: @client, redirect_uri: @redirect_uri,
        scope: params[:allow_write] == "1" ? OauthGrant::SCOPES.join(" ") : OauthGrant::SCOPE, # quem decide é o usuário, na tela
        resource: params[:resource].to_s.first(300).presence, code_challenge: @code_challenge
      )
      redirect_back_to_client(code: grant.issue_code!)
    end

    # PATCH /oauth/grants/:id — liga/desliga a permissão de alterar, pela página de configuração.
    def update
      grant = current_account.oauth_grants.find(params[:id])
      grant.allow_write!(params[:allow_write] == "1")
      redirect_to setup_path(anchor: "mcp"), notice: t(grant.write? ? "flash.mcp.write_on" : "flash.mcp.write_off")
    end

    # DELETE /oauth/grants/:id — revogar pela página de configuração.
    def destroy
      current_account.oauth_grants.find(params[:id]).revoke!
      redirect_to setup_path(anchor: "mcp"), notice: t("flash.mcp.grant_revoked")
    end

    private

    # Valida o pedido. Cliente ou redirect inválido NÃO redireciona (não se manda
    # o usuário para um endereço não confiável): mostra erro aqui mesmo.
    def load_request
      @client = Oauth::ClientResolver.call(params[:client_id])
      @redirect_uri = params[:redirect_uri].to_s
      return render_invalid(:unknown_client) if @client.nil?
      return render_invalid(:bad_redirect) unless @client.redirect_uri_allowed?(@redirect_uri)

      @state = params[:state].to_s.presence
      @code_challenge = params[:code_challenge].to_s
      return redirect_back_to_client(error: "unsupported_response_type") unless params[:response_type] == "code"

      redirect_back_to_client(error: "invalid_request", error_description: "PKCE S256 obrigatório") unless pkce_ok?
    end

    def pkce_ok?
      params[:code_challenge_method] == "S256" && @code_challenge.match?(/\A[A-Za-z0-9\-._~]{43,128}\z/)
    end

    def render_invalid(reason)
      @reason = reason
      render :invalid, status: :bad_request
    end

    def redirect_back_to_client(extra)
      uri = URI.parse(@redirect_uri)
      query = URI.decode_www_form(uri.query.to_s) + extra.merge(state: @state).compact.map { |k, v| [k.to_s, v] }
      uri.query = URI.encode_www_form(query)
      redirect_to uri.to_s, allow_other_host: true
    end
  end
end
