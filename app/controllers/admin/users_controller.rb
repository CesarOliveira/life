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
          alert: "Você não pode remover sua própria role de admin." and return
      end

      if params[:grant] == "1"
        user.add_role(role)
        notice = "Role '#{role}' concedida a #{user.email}."
      else
        user.remove_role(role)
        notice = "Role '#{role}' removida de #{user.email}."
      end
      redirect_to admin_users_path, notice: notice
    end
  end
end
