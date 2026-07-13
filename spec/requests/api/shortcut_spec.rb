require "rails_helper"

RSpec.describe "API::Shortcut", type: :request do
  let(:account) { create(:account, api_token: "tok_sc_123") }
  let(:headers) { { "Authorization" => "Bearer tok_sc_123" } }

  it "rejeita sem token" do
    get "/api/shortcut"
    expect(response).to have_http_status(:unauthorized)
  end

  it "devolve o atalho (.shortcut) com o token embutido e sem pergunta de import" do
    account
    get "/api/shortcut", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Disposition"]).to include(".shortcut")
    body = response.body
    expect(body).to include("tok_sc_123")          # token embutido
    expect(body).to include("/api/usage_raw")       # posta no tempo de tela
    expect(body).to include("<array/>")             # WFWorkflowImportQuestions vazio
    expect(body).not_to include("Cole seu token")   # não pergunta o token
  end
end
