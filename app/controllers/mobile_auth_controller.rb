# Login do app nativo (Caminho B): reusa o OAuth Google web. O app abre
# /mobile/login num navegador embutido (ASWebAuthenticationSession); marcamos a
# sessão como mobile e disparamos o handshake do Google via POST (exigido pelo
# omniauth-rails_csrf_protection). O callback devolve o token por deep link.
class MobileAuthController < ApplicationController
  skip_before_action :authenticate_user!, only: :login

  def login
    session[:mobile_auth] = true
    render :login, layout: false
  end
end
