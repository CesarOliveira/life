# Exclusão da própria conta. A URL /delete-account é pública e estável (é a que
# vai no cadastro da App Store); sem login, o Devise leva ao login e volta.
class UserDeletionsController < ApplicationController
  skip_before_action :ensure_personal_account
  skip_before_action :require_account

  CONFIRMATION = "EXCLUIR".freeze

  def new
    @deletion = UserDeletion.new(current_user)
    @accounts = current_user.accounts.distinct.includes(:memberships).to_a
  end

  def destroy
    unless params[:confirmation].to_s.strip.casecmp?(CONFIRMATION)
      return redirect_to(delete_account_path, alert: t("user_deletion.wrong_confirmation", word: CONFIRMATION))
    end

    result = UserDeletion.new(current_user).call
    return redirect_to(delete_account_path, alert: t("user_deletion.blocked.#{result.error}")) unless result.ok?

    sign_out(:user)
    reset_session
    redirect_to root_path, notice: t("user_deletion.done")
  end
end
