# Site institucional da Integrattor (integrattor.com.br), a holding dona do
# Life. Página estática servida por este app só para economizar infraestrutura:
# as rotas ficam presas ao host (config/routes.rb), então nada do Life aparece
# nesse domínio. Fonte da página: ~/Sites/integrattor.com.br (index.html).
class CorporateController < ActionController::Base
  def show
    response.set_header("Cache-Control", "public, max-age=300")
    render :show, layout: false
  end

  # www.integrattor.com.br e qualquer outro caminho voltam para a raiz.
  def redirect_home
    redirect_to "https://integrattor.com.br/", status: :moved_permanently, allow_other_host: true
  end
end
