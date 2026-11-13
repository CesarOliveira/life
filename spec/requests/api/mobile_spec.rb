require "rails_helper"

RSpec.describe "API::Mobile", type: :request do
  let(:user) { create(:user, name: "Ana", email: "ana@example.com") }
  let(:account) { create(:account, owner: user) }
  let(:headers) { { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" } }
  let(:json) { { "CONTENT_TYPE" => "application/json" } }

  before { create(:membership, user: user, account: account, role: "owner", status: "active") }

  describe "POST /api/mobile/session (e-mail e senha)" do
    it "returns the account token for valid credentials, case-insensitive on the e-mail" do
      post "/api/mobile/session", params: { email: "Ana@Example.com ", password: "password123" }.to_json, headers: json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("token" => account.reload.api_token, "user" => { "name" => "Ana", "email" => "ana@example.com" })
    end

    it "answers the same way for a wrong password and an unknown e-mail" do
      post "/api/mobile/session", params: { email: "ana@example.com", password: "errada" }.to_json, headers: json
      wrong = [response.status, response.body]
      post "/api/mobile/session", params: { email: "ninguem@example.com", password: "password123" }.to_json, headers: json
      expect([response.status, response.body]).to eq(wrong)
      expect(wrong.first).to eq(401)
    end

    it "creates the personal account on first login of a user without one" do
      fresh = create(:user)
      expect { post "/api/mobile/session", params: { email: fresh.email, password: "password123" }.to_json, headers: json }
        .to change(Account, :count).by(1)
      expect(JSON.parse(response.body)["token"]).to eq(fresh.accounts.first.api_token)
    end
  end

  describe "POST /api/mobile/session/apple" do
    let(:rsa) { OpenSSL::PKey::RSA.new(2048) }
    let(:jwk) { JWT::JWK.new(rsa, kid: "test-key") }
    let(:claims) do
      { iss: "https://appleid.apple.com", aud: "online.cesaroliveira.lifeApp", sub: "001234.abc", email: "maria@privaterelay.appleid.com",
        email_verified: "true", iat: Time.current.to_i, exp: 10.minutes.from_now.to_i }
    end

    def token_for(payload, key: rsa)
      JWT.encode(payload, key, "RS256", { kid: "test-key" })
    end

    before { allow(AppleIdentityToken).to receive(:jwks).and_return(JSON.parse({ keys: [jwk.export] }.to_json)) }

    it "creates a user on first sign-in and recognizes the same Apple id afterwards" do
      expect { post "/api/mobile/session/apple", params: { identity_token: token_for(claims), name: "Maria Silva" }.to_json, headers: json }
        .to change(User, :count).by(1)
      expect(response).to have_http_status(:ok)
      created = User.find_by!(apple_uid: "001234.abc")
      expect(created).to have_attributes(name: "Maria Silva", email: "maria@privaterelay.appleid.com")

      # no segundo login a Apple não manda mais o nome; o e-mail do token pode até mudar
      expect { post "/api/mobile/session/apple", params: { identity_token: token_for(claims.merge(email: "outro@privaterelay.appleid.com")) }.to_json, headers: json }
        .not_to change(User, :count)
      expect(JSON.parse(response.body)["token"]).to eq(created.accounts.first.api_token)
    end

    it "links to an existing user by verified e-mail without touching the Google login" do
      user.update!(provider: "google_oauth2", uid: "g-1")
      post "/api/mobile/session/apple", params: { identity_token: token_for(claims.merge(email: "ana@example.com")) }.to_json, headers: json
      expect(JSON.parse(response.body)["token"]).to eq(account.reload.api_token)
      expect(user.reload).to have_attributes(apple_uid: "001234.abc", provider: "google_oauth2", uid: "g-1")
    end

    it "rejects tokens for another app, expired, from another issuer, signed by another key, or unverified e-mail of someone else" do
      bad = [
        token_for(claims.merge(aud: "com.outro.app")),
        token_for(claims.merge(exp: 1.minute.ago.to_i)),
        token_for(claims.merge(iss: "https://evil.example")),
        token_for(claims, key: OpenSSL::PKey::RSA.new(2048)),
        "nao-e-um-jwt"
      ]
      bad.each do |token|
        post "/api/mobile/session/apple", params: { identity_token: token }.to_json, headers: json
        expect(response).to have_http_status(:unauthorized)
      end
      post "/api/mobile/session/apple", params: { identity_token: token_for(claims.merge(email: "ana@example.com", email_verified: "false")) }.to_json, headers: json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.apple_uid).to be_nil
    end
  end

  describe "GET /api/mobile/summary" do
    it "requires the token" do
      get "/api/mobile/summary"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the native home data: sleep, activity, heart, screen time, tasks and today's habits" do
      yesterday = Date.current - 1
      { "sleep_minutes" => 430, "sleep_bedtime" => 1380, "sleep_wake" => 410, "sleep_deep_minutes" => 60, "steps" => 9012,
        "exercise_minutes" => 42, "active_energy" => 600, "move_goal" => 500, "resting_hr" => 58, "hrv" => 47.6 }.each do |key, value|
        create(:measurement, account: account, key: key, value: value, category: "health", measured_on: yesterday)
      end
      create(:app_usage, account: account, bundle_id: "Instagram", name: "Instagram", date: yesterday, seconds: 6000)
      create(:app_usage, account: account, bundle_id: "WhatsApp", name: "WhatsApp", date: yesterday, seconds: 1200)
      board = TaskBoard.create_with_columns!(account: account, name: "Pessoal")
      board.tasks.create!(account: account, task_column: board.columns.first, title: "Vencida", due_on: yesterday)
      board.tasks.create!(account: account, task_column: board.columns.last, title: "Feita", completed_at: Time.current)
      category = create(:habit_category, account: account)
      manual = create(:habit, account: account, habit_category: category, name: "Ler")
      manual.habit_checks.create!(date: Date.current)
      create(:habit, :auto_screen_time, account: account, habit_category: category, name: "Tela")
      create(:measurement, account: create(:account), key: "steps", value: 1, category: "health", measured_on: Date.current) # outra conta

      get "/api/mobile/summary", headers: headers
      data = JSON.parse(response.body)
      expect(data["user"]).to eq("name" => "Ana", "email" => "ana@example.com")
      expect(data["sleep"]).to include("minutes" => 430, "bedtime" => "23:00", "wake" => "06:50")
      expect(data["sleep"]["stages"].first).to include("key" => "sleep_deep_minutes", "minutes" => 60)
      expect(data["activity"]).to include("steps" => 9012, "exercise_minutes" => 42, "active_energy" => 600, "move_goal" => 500)
      expect(data["heart"]).to include("resting_hr" => 58, "hrv" => 47.6)
      expect(data["screen_time"]).to include("minutes" => 120, "top_apps" => [{ "app" => "Instagram", "minutes" => 100 }, { "app" => "WhatsApp", "minutes" => 20 }])
      expect(data["tasks"]).to include("open" => 1, "overdue" => 1)
      expect(data["tasks"]["items"].first).to include("title" => "Vencida", "overdue" => true)
      expect(data["habits"].map { |h| [h["name"], h["automatic"], h["done"]] }).to contain_exactly(["Ler", false, true], ["Tela", true, false])
    end

    it "returns an empty but valid summary for a brand-new account" do
      get "/api/mobile/summary", headers: headers
      expect(JSON.parse(response.body)).to include("sleep" => nil, "activity" => nil, "screen_time" => nil, "habits" => [], "tasks" => { "open" => 0, "overdue" => 0, "items" => [] })
    end
  end

  describe "habits, quick task and account deletion" do
    it "toggles a manual habit and refuses automatic ones and other accounts' habits" do
      category = create(:habit_category, account: account)
      manual = create(:habit, account: account, habit_category: category)
      auto = create(:habit, :auto_screen_time, account: account, habit_category: category)

      post "/api/mobile/habits/#{manual.id}/toggle", headers: headers
      expect(JSON.parse(response.body)).to include("done" => true)
      post "/api/mobile/habits/#{manual.id}/toggle", headers: headers
      expect(JSON.parse(response.body)).to include("done" => false)
      expect(manual.habit_checks.count).to eq(0)

      post "/api/mobile/habits/#{auto.id}/toggle", headers: headers
      expect(JSON.parse(response.body)["error"]).to eq("automatic_habit")

      foreign = create(:habit, account: create(:account), habit_category: create(:habit_category))
      post "/api/mobile/habits/#{foreign.id}/toggle", headers: headers
      expect(JSON.parse(response.body)["error"]).to eq("not_found")
    end

    it "captures a quick task, creating a default board when there is none" do
      expect { post "/api/mobile/tasks", params: { title: "Comprar tinta" }.to_json, headers: headers }
        .to change(account.task_boards, :count).by(1).and change(account.tasks, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(account.tasks.last).to have_attributes(title: "Comprar tinta", creator: user)
      expect(account.tasks.last.task_column.name).to eq("A fazer")

      post "/api/mobile/tasks", params: { title: " " }.to_json, headers: headers
      expect(JSON.parse(response.body)["error"]).to eq("blank_title")
    end

    it "deletes the account from inside the app only with the typed confirmation" do
      delete "/api/mobile/account", params: { confirm: "sim" }.to_json, headers: headers
      expect(JSON.parse(response.body)["error"]).to eq("confirmation_required")
      expect(User.exists?(user.id)).to be(true)

      delete "/api/mobile/account", params: { confirm: "EXCLUIR" }.to_json, headers: headers
      expect(JSON.parse(response.body)).to eq("ok" => true)
      expect(User.exists?(user.id)).to be(false)
      get "/api/mobile/summary", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
