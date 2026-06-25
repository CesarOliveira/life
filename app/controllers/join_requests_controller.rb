class JoinRequestsController < ApplicationController
  # Solicitar entrada não exige conta ativa prévia.
  skip_before_action :require_account

  def new
  end

  def create
    account = Account.find_by(join_code: params[:join_code].to_s.strip)

    unless account
      flash.now[:alert] = t("flash.join_requests.invalid_code")
      render :new, status: :unprocessable_entity and return
    end

    existing = current_user.membership_for(account)
    if existing&.active?
      session[:account_id] = account.id
      redirect_to authenticated_root_path, notice: t("flash.join_requests.already_member", account: account.name) and return
    elsif existing
      redirect_to pending_approval_path, notice: t("flash.join_requests.already_requested", account: account.name) and return
    end

    current_user.memberships.create!(account: account, role: "member", status: "pending")
    redirect_to pending_approval_path, notice: t("flash.join_requests.sent", account: account.name)
  end
end
