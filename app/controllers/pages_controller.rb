# Páginas públicas exigidas para publicar o app: política de privacidade, termos
# de uso e suporte. Sem login. O texto fica em templates por idioma
# (ex.: privacy.pt-BR.html.erb); os dados do responsável vêm de config/legal.yml.
class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_personal_account
  skip_before_action :require_account

  before_action { @legal = Rails.application.config_for(:legal) }

  def privacy; end

  def terms; end

  def support; end
end
