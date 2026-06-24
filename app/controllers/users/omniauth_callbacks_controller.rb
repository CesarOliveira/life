class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Callback do Google. O fluxo de conta/onboarding fica a cargo do
  # ApplicationController#require_account depois do sign_in.
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user&.persisted?
      flash[:notice] = "Login com o Google realizado com sucesso."
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "Não foi possível entrar com o Google. " \
                      "Tente novamente ou use e-mail e senha."
      redirect_to new_user_session_path
    end
  end

  # Qualquer falha no handshake (usuário cancelou, credencial inválida, etc.).
  def failure
    flash[:alert] = "Login com o Google cancelado ou indisponível."
    redirect_to new_user_session_path
  end
end
