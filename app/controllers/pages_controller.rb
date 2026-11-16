# Páginas públicas exigidas para publicar o app: política de privacidade, termos
# de uso e suporte. Sem login. O texto fica em templates por idioma
# (ex.: privacy.pt-BR.html.erb); os dados do responsável vêm de config/legal.yml.
class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_personal_account
  skip_before_action :require_account

  before_action { @legal = Rails.application.config_for(:legal) }

  # Apresentação pública (raiz do site para quem não está logado).
  def home
    @mac_app = Rails.application.config_for(:mac_app)
    @store = Rails.application.config_for(:store_links)
  end

  def privacy; end

  def terms; end

  def support; end

  # Página de download do Life para Mac (coletor do tempo de tela do iPhone).
  def mac
    @mac_app = Rails.application.config_for(:mac_app)
  end

  # Endereço estável para a versão atual: /mac/download -> /downloads/Life-x.y.z.dmg
  def mac_download
    redirect_to "/downloads/#{Rails.application.config_for(:mac_app)[:file]}", allow_other_host: false
  end
end
