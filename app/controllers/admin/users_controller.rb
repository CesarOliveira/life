module Admin
  class UsersController < BaseController
    def index
      @users = User.includes(:roles, memberships: :account).order(:created_at)
    end

    # Concede/remove uma role do usuário (params: role, grant=1|0).
    def update
      user = User.find(params[:id])
      role = params[:role].to_s

      if params[:grant] != "1" && role == Role::ADMIN && user == current_user
        redirect_to admin_users_path,
          alert: t("flash.admin_users.cant_remove_own_admin") and return
      end

      if params[:grant] == "1"
        user.add_role(role)
        notice = t("flash.admin_users.role_granted", role: role, email: user.email)
      else
        user.remove_role(role)
        notice = t("flash.admin_users.role_removed", role: role, email: user.email)
      end
      redirect_to admin_users_path, notice: notice
    end
  end
end
