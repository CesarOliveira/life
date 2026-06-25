module Admin
  # Aprovação/recusa de vínculos pendentes (platform-wide). Diferente do
  # MembershipsController de conta (que é escopado por conta e aprovado pelo
  # admin daquela conta).
  class MembershipsController < BaseController
    def update
      membership = Membership.find(params[:id])
      membership.update!(status: "active")
      redirect_to admin_root_path,
        notice: t("flash.admin_memberships.approved", email: membership.user.email, account: membership.account.name)
    end

    def destroy
      membership = Membership.find(params[:id])
      email = membership.user.email
      membership.destroy
      redirect_to admin_root_path, notice: t("flash.admin_memberships.refused", email: email)
    end
  end
end
