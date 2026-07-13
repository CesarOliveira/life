require "rails_helper"
require "rexml/document"

RSpec.describe HealthShortcutBuilder do
  subject(:xml) { described_class.new(endpoint: "https://x.test/api/usage_raw").plist }

  it "monta só o bloco de Tempo de tela e posta em /api/usage_raw" do
    expect(xml).to include("https://x.test/api/usage_raw")
    expect(xml).to include(described_class::ACTIVITY_ACTION_ID)
    expect(xml).to include("activityType")
    # um POST só (tempo de tela); a Saúde saiu (migrou pro app nativo)
    expect(xml.scan("is.workflow.actions.downloadurl").size).to eq(1)
  end

  it "não coleta mais Saúde (sem HealthKit no atalho)" do
    expect(xml).not_to include("health.quantity")
    expect(xml).not_to include("filter.health")
    expect(xml).not_to include("is.workflow.actions.statistics")
    expect(xml).not_to include("/api/health_raw")
  end

  it "coage cada item da atividade a texto e combina os Repeat Results" do
    expect(xml).to include("is.workflow.actions.repeat.each")
    expect(xml).to include("is.workflow.actions.text.combine")
    expect(xml).to include("Repeat Item")
    expect(xml).to include("Repeat Results")
  end

  it "carrega o marcador de versão e pede o token na importação" do
    expect(xml).to include("client_version=#{described_class::VERSION}")
    expect(xml).to include("WFWorkflowImportQuestions")
    expect(xml).to include("Cole seu token")
    expect(xml).to include("Bearer ")
    expect(xml).to include("<integer>#{described_class::TOKEN_ACTION_INDEX}</integer>")
  end

  it "produz XML bem-formado" do
    expect { REXML::Document.new(xml) }.not_to raise_error
  end
end
