class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Callback do Google. O fluxo de conta/onboarding fica a cargo do
  # ApplicationController#require_account depois do sign_in.
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user&.persisted?
      return deliver_token_to_app(@user) if session.delete(:mobile_auth)

      flash[:notice] = t("flash.omniauth.success")
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = t("flash.omniauth.failure")
      redirect_to new_user_session_path
    end
  end

  # Qualquer falha no handshake (usuário cancelou, credencial inválida, etc.).
  def failure
    flash[:alert] = t("flash.omniauth.cancelled")
    redirect_to new_user_session_path
  end

  private

  # Login do app nativo (Caminho B): garante a conta pessoal + token e entrega
  # ao app por deep link (lifeapp://). NÃO abre sessão web.
  def deliver_token_to_app(user)
    account = Account.ensure_personal_for(user, locale: I18n.locale)
    account.regenerate_api_token if account.api_token.blank?
    @token = account.api_token
    render "users/omniauth_callbacks/mobile_redirect", layout: false
  end
end
