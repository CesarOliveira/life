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
    expect(body).to include(I18n.t("pages.draft")) # config/legal.yml ainda em rascunho

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
end
