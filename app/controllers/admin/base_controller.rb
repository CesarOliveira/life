module Admin
  # Base de todo o /admin: exige usuário autenticado (ApplicationController) E
  # administrador da plataforma. Independe de conta ativa (admin não é tenant).
  class BaseController < ApplicationController
    skip_before_action :require_account
    before_action :require_platform_admin
    layout "admin"

    private

    def require_platform_admin
      return if current_user&.platform_admin?

      redirect_to authenticated_root_path,
        alert: "Acesso restrito ao administrador da plataforma."
    end
  end
end
