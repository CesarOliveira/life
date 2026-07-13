# Login do app nativo (Caminho B): reusa o OAuth Google web. O app abre
# /mobile/login num navegador embutido (ASWebAuthenticationSession); marcamos a
# sessão como mobile e disparamos o handshake do Google via POST (exigido pelo
# omniauth-rails_csrf_protection). O callback devolve o token por deep link.
class MobileAuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :enter]

  # Ponte token->sessão: o app abre o WebView em /mobile/enter?token=<api_token>
  # e ganha uma sessão web (assim vê o Life inteiro logado). O token já dá acesso
  # total à conta pela API, então não amplia a exposição; filtramos dos logs.
  def enter
    account = Account.find_by(api_token: params[:token].to_s.strip)
    user = account&.owner || account&.users&.first
    return redirect_to(new_user_session_path, alert: t("flash.omniauth.failure")) unless user

    sign_in(user)
    # Marca a sessão como "app nativo" (some no navegador). A tela Configurar usa
    # isso pra oferecer o atalho com token embutido em vez do assinado+colar.
    cookies[:life_app] = { value: "1", expires: 1.year.from_now, httponly: true }
    redirect_to root_path
  end

  def login
    # A sessão não sobrevive à volta do Google no navegador embutido, então
    # marcamos o fluxo num cookie CROSS-SITE (SameSite=None) que sobrevive.
    # session[:mobile_auth] fica como reforço (fluxos same-site / testes).
    session[:mobile_auth] = true
    cookies[:mobile_flow] = {
      value: "1",
      expires: 10.minutes.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :none
    }
    render :login, layout: false
  end
end
