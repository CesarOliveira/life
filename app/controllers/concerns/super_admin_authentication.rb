# Auth do ActiveAdmin (/super_admin). Incluído no ActiveAdmin::BaseController
# (que herda de ActionController::Base, onde o Devise já injeta current_user/
# authenticate_user!). Exige login + a role "super_admin".
module SuperAdminAuthentication
  def authenticate_super_admin!
    authenticate_user!
    return if current_user&.super_admin?

    redirect_to main_app.authenticated_root_path, alert: I18n.t("flash.super_admin.access_restricted")
  end
end
