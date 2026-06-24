module Admin
  class AccountsController < BaseController
    def index
      @accounts = Account.includes(:owner, :memberships).order(:created_at)
    end
  end
end
