require "rails_helper"

RSpec.describe "Personal account", type: :request do
  it "is auto-created on the first authenticated visit (no onboarding)" do
    user = create(:user)
    sign_in user

    expect { get habits_path }.to change(Account, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(user.reload.accounts.count).to eq(1)
  end

  it "creates the personal account in the signup language (session locale)" do
    user = create(:user)
    sign_in user

    get habits_path(locale: "en") # idioma escolhido no cadastro fica na sessão
    account = user.reload.accounts.first
    expect(account.locale).to eq("en")
    expect(account.habit_categories.ordered.pluck(:name))
      .to eq(%w[Health Performance Mind Relationships])
  end
end
