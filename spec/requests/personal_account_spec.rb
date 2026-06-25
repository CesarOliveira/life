require "rails_helper"

RSpec.describe "Personal account", type: :request do
  it "is auto-created on the first authenticated visit (no onboarding)" do
    user = create(:user)
    sign_in user

    expect { get habits_path }.to change(Account, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(user.reload.accounts.count).to eq(1)
  end
end
