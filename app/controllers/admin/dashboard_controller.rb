module Admin
  class DashboardController < BaseController
    def index
      @pending_memberships = Membership.pending.includes(:user, :account).order(:created_at)
      @users_count    = User.count
      @accounts_count = Account.count
      @active_count   = Membership.active.count
    end
  end
end
