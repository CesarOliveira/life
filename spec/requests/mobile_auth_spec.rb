require "rails_helper"

RSpec.describe "Mobile auth (Caminho B)", type: :request do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "mob-1",
      info: { email: "mob@example.com", name: "Mob User" }
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end

  after { OmniAuth.config.test_mode = false }

  it "GET /mobile/login marca a sessão e dispara o POST do Google" do
    get "/mobile/login"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/users/auth/google_oauth2")
  end

  it "no fluxo mobile, o callback devolve o token da conta por deep link (sem sessão web)" do
    get "/mobile/login" # marca session[:mobile_auth]
    expect {
      get user_google_oauth2_omniauth_callback_path
    }.to change(User, :count).by(1)

    account = User.find_by(email: "mob@example.com").accounts.first
    expect(account.api_token).to be_present
    expect(response).to have_http_status(:ok) # página de deep link, não redirect
    expect(response.body).to include("lifeapp://auth?token=#{account.api_token}")
  end

  it "no fluxo web normal, segue logando por sessão (sem deep link)" do
    get user_google_oauth2_omniauth_callback_path # sem passar por /mobile/login
    expect(response).to have_http_status(:redirect)
    expect(response.body).not_to include("lifeapp://")
  end

  describe "GET /mobile/enter (ponte token->sessão do WebView)" do
    it "loga a sessão a partir do api_token e abre o app" do
      user = create(:user)
      account = Account.ensure_personal_for(user)

      get "/mobile/enter", params: { token: account.api_token }
      expect(response).to redirect_to(root_path)

      get root_path # já autenticado: não volta pro login
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it "rejeita token inválido" do
      get "/mobile/enter", params: { token: "nao-existe" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
