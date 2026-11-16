require "rails_helper"

RSpec.describe "Public pages", type: :request do
  it "serves privacy, terms and support without login, in Portuguese and English URLs" do
    %w[/privacidade /privacy /termos /terms /suporte /support].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
  end

  it "states the HealthKit commitments Apple requires and how to delete the account" do
    get privacy_path
    body = response.body
    expect(body).to include("HealthKit", "publicidade", "iCloud", "Anthropic", "/delete-account")
    expect(body).not_to include(I18n.t("pages.draft")) # config/legal.yml publicado
    expect(body).to include("23.001.652/0001-46", "cesar@integrattor.com.br")

    get privacy_path(locale: "en")
    expect(response.body).to include("Privacy Policy", "advertising", "not</strong> sold")
  end

  it "shows the operator and hides the draft notice once config/legal.yml is filled" do
    legal = { status: "published", product_name: "Life", legal_name: "Empresa Exemplo Ltda.", tax_id: "00.000.000/0001-00",
              contact_email: "contato@example.com", effective_date: "2026-11-13" }
    allow(Rails.application).to receive(:config_for).and_call_original
    allow(Rails.application).to receive(:config_for).with(:legal).and_return(legal)

    get support_path
    expect(response.body).to include("Empresa Exemplo Ltda.", "00.000.000/0001-00", "mailto:contato@example.com")
    expect(response.body).not_to include(I18n.t("pages.draft"))
  end

  it "serves the Life for Mac page and redirects the stable download link to the current DMG" do
    mac = Rails.application.config_for(:mac_app)
    get mac_app_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Life para Mac", "Acesso Total ao Disco", mac[:sha256], mac_download_path)

    get mac_download_path
    expect(response).to redirect_to("/downloads/#{mac[:file]}")
    expect(Rails.public_path.join("downloads", mac[:file])).to exist
    expect(Digest::SHA256.file(Rails.public_path.join("downloads", mac[:file])).hexdigest).to eq(mac[:sha256])
  end

  it "shows the landing page at the root for visitors, with the free pricing promise" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Criar conta grátis", "tudo o que existe hoje nunca vai ser cobrado",
                                      "Vantagens e limitações", new_user_registration_path, mac_app_path)
    expect(response.body).to include("em breve na App Store") # até a Apple aprovar

    get root_path(locale: "en")
    expect(response.body).to include("Create a free account", "will never be charged for")
  end

  it "states the pricing commitment in the terms" do
    get terms_path
    expect(response.body).to include("6. Preço", "nunca serão cobrados", "não passará a ser pago")
    get terms_path(locale: "en")
    expect(response.body).to include("6. Pricing", "will never be charged for")
  end

  it "keeps signed-in users on the dashboard at the root" do
    user = create(:user)
    account = create(:account, owner: user)
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
    get root_path
    expect(response.body).not_to include("Criar conta grátis")
  end
end
