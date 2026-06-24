require "rails_helper"

RSpec.describe "Admin panel", type: :request do
  let(:admin)   { create(:user, :admin, email: "boss@example.com") }
  let(:regular) { create(:user, email: "rando@example.com") }

  context "as a non-admin user" do
    before { sign_in regular }

    it "blocks access to /admin" do
      get admin_root_path
      expect(response).to redirect_to(authenticated_root_path)
    end
  end

  context "as a platform admin" do
    before { sign_in admin }

    it "renders the dashboard" do
      get admin_root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Painel administrativo")
    end

    it "approves a pending membership" do
      account = create(:account, owner: regular)
      membership = create(:membership, :pending, user: regular, account: account)

      patch admin_membership_path(membership)

      expect(membership.reload.status).to eq("active")
      expect(response).to redirect_to(admin_root_path)
    end

    it "rejects (destroys) a pending membership" do
      account = create(:account, owner: regular)
      membership = create(:membership, :pending, user: regular, account: account)

      expect {
        delete admin_membership_path(membership)
      }.to change(Membership, :count).by(-1)
    end

    it "grants a role to a user" do
      patch admin_user_path(regular, role: "admin", grant: "1")
      expect(regular.reload.role?(:admin)).to be true
    end

    it "removes a role from a user" do
      regular.add_role(:admin)
      patch admin_user_path(regular, role: "admin", grant: "0")
      expect(regular.reload.role?(:admin)).to be false
    end

    it "won't let an admin remove their own admin role" do
      patch admin_user_path(admin, role: "admin", grant: "0")
      expect(admin.reload.role?(:admin)).to be true
    end

    it "renders the CRUD index pages (trades, positions, assets)" do
      get admin_trades_path
      expect(response).to have_http_status(:ok)
      get admin_positions_path
      expect(response).to have_http_status(:ok)
      get admin_assets_path
      expect(response).to have_http_status(:ok)
    end
  end
end
