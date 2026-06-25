class OnboardingController < ApplicationController
  # Usuário ainda sem conta ativa não passa pelo guard de conta.
  skip_before_action :require_account
  skip_before_action :ensure_personal_account

  def show
    redirect_to authenticated_root_path and return if current_account

    @account = Account.new
    @pending = current_user.memberships.pending.includes(:account)
  end

  def pending
    redirect_to authenticated_root_path and return if current_account

    @pending = current_user.memberships.pending.includes(:account)
  end
end
