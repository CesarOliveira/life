require "rails_helper"

RSpec.describe "Account creation (manual approval)", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  context "when the user is NOT a platform admin" do
    it "creates a pending membership and redirects to the pending screen" do
      expect {
        post accounts_path, params: { account: { name: "Minha Conta" } }
      }.to change(Account, :count).by(1)

      membership = Account.last.memberships.find_by(user: user)
      expect(membership.status).to eq("pending")
      expect(response).to redirect_to(pending_approval_path)
    end
  end

  context "when the user IS a platform admin" do
    before { user.add_role(:admin) }

    it "creates an active membership and redirects to the dashboard" do
      post accounts_path, params: { account: { name: "Conta Admin" } }

      membership = Account.last.memberships.find_by(user: user)
      expect(membership.status).to eq("active")
      expect(response).to redirect_to(authenticated_root_path)
    end
  end
end
