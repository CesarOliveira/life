require "rails_helper"

RSpec.describe "Delete my account", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before { create(:membership, user: user, account: account, role: "owner", status: "active") }

  it "asks for login first, then shows what will be deleted" do
    get delete_account_path
    expect(response).to redirect_to(new_user_session_path)

    sign_in user
    get delete_account_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email, I18n.t("user_deletion.irreversible"), "EXCLUIR")
  end

  it "does nothing without the typed confirmation" do
    sign_in user
    delete delete_account_path, params: { confirmation: "sim" }
    expect(response).to redirect_to(delete_account_path)
    expect(User.exists?(user.id)).to be(true)
  end

  it "deletes the user, signs out and stops the tokens from working" do
    token = account.api_token
    sign_in user
    delete delete_account_path, params: { confirmation: "excluir" }
    expect(response).to redirect_to(root_path)
    expect(User.exists?(user.id)).to be(false)

    get habits_path
    expect(response).to redirect_to(new_user_session_path)
    post "/api/usage", params: { apps: [] }.to_json, headers: { "Authorization" => "Bearer #{token}", "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "links to the deletion page from the account settings and blocks platform admins" do
    sign_in user
    get edit_account_path(account)
    expect(response.body).to include(delete_account_path)

    user.add_role(:admin)
    get delete_account_path
    expect(response.body).to include(I18n.t("user_deletion.blocked.platform_admin"))
    delete delete_account_path, params: { confirmation: "EXCLUIR" }
    expect(User.exists?(user.id)).to be(true)
  end
end
