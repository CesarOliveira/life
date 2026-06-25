class MembershipsController < ApplicationController
  before_action :set_account
  before_action :require_account_admin

  def index
    @active_memberships  = @account.memberships.active.includes(:user).order(:role)
    @pending_memberships = @account.memberships.pending.includes(:user).order(:created_at)
  end

  # Aprovar (status -> active) ou alterar papel de um membro.
  def update
    membership = @account.memberships.find(params[:id])

    if params[:approve].present?
      membership.update!(status: "active")
      notice = t("flash.memberships.approved", email: membership.user.email)
    elsif params[:role].present? && Membership::ROLES.include?(params[:role])
      membership.update!(role: params[:role])
      notice = t("flash.memberships.role_updated")
    else
      notice = t("flash.memberships.nothing")
    end

    redirect_to account_members_path(@account), notice: notice
  end

  # Remover/rejeitar um membro (não permite remover o dono).
  def destroy
    membership = @account.memberships.find(params[:id])
    if membership.owner?
      redirect_to account_members_path(@account), alert: t("flash.memberships.owner_cant_remove")
    else
      membership.destroy
      redirect_to account_members_path(@account), notice: t("flash.memberships.removed")
    end
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def require_account_admin
    return if current_user.admin_of?(@account)
    redirect_to authenticated_root_path, alert: t("flash.memberships.access_restricted")
  end
end
