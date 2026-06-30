require "rails_helper"
require "rexml/document"

RSpec.describe HealthShortcutBuilder do
  subject(:xml) { described_class.new(endpoint: "https://x.test/api/health_raw").plist }

  it "posts to the raw endpoint without any in-shortcut calculation" do
    expect(xml).to include("https://x.test/api/health_raw")
    expect(xml).to include("is.workflow.actions.downloadurl")
    expect(xml).not_to include("is.workflow.actions.statistics")
  end

  it "extracts each sample's Value in a loop to dodge the iOS Health-share block" do
    expect(xml).to include("is.workflow.actions.filter.health.quantity")
    expect(xml).to include("is.workflow.actions.repeat.each")
    expect(xml).to include("is.workflow.actions.properties.health.quantity")
    expect(xml).to include("<string>Value</string>")
    expect(xml).to include("is.workflow.actions.text.combine")
  end

  it "feeds the current Repeat Item into Get Details and combines the Repeat Results" do
    expect(xml).to include("Repeat Item")
    expect(xml).to include("Repeat Results")
  end

  it "carries the version marker and one POST per metric in the URL" do
    expect(xml).to include("client_version=#{described_class::VERSION}")
    expect(xml).to include("key=steps")
    expect(xml).to include("key=resting_hr")
  end

  it "has a find action per metric and a POST per metric plus screen time" do
    expect(xml.scan("is.workflow.actions.filter.health.quantity").size).to eq(described_class::METRICS.size)
    # um POST por métrica de saúde + um POST de tempo de tela
    expect(xml.scan("is.workflow.actions.downloadurl").size).to eq(described_class::METRICS.size + 1)
  end

  it "includes the screen-time block (App Activity -> usage_raw)" do
    expect(xml).to include(described_class::ACTIVITY_ACTION_ID)
    expect(xml).to include("/api/usage_raw")
    expect(xml).to include("activityType")
  end

  it "asks for the token at import time, targeting the token action index" do
    expect(xml).to include("WFWorkflowImportQuestions")
    expect(xml).to include("Cole seu token")
    expect(xml).to include("<integer>#{described_class::TOKEN_ACTION_INDEX}</integer>")
    expect(xml).to include("Bearer ")
  end

  it "produces well-formed XML" do
    expect { REXML::Document.new(xml) }.not_to raise_error
  end
end
