require "rails_helper"

RSpec.describe "Integrattor site", type: :request do
  it "serves the holding page on integrattor.com.br, with all four companies" do
    host! "integrattor.com.br"
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Integrattor", "Vem Pra Tela", "ImovelBase", "Espaço Esmeralda", "life.integrattor.com.br")
  end

  it "never exposes Life routes on the corporate domain and sends www to the apex" do
    host! "integrattor.com.br"
    %w[/users/sign_in /api/mobile/summary /mcp /privacidade].each do |path|
      get path
      expect(response).to redirect_to("https://integrattor.com.br/"), path
    end
    host! "www.integrattor.com.br"
    get "/"
    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("https://integrattor.com.br/")
  end

  it "keeps Life working on its own host" do
    host! "life.integrattor.com.br"
    get "/privacidade"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Nossas empresas")
  end
end
