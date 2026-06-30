require "rails_helper"
require "rexml/document"

RSpec.describe HealthShortcutBuilder do
  subject(:xml) { described_class.new(endpoint: "https://x.test/api/health_raw").plist }

  it "is a dumb pipe: collects samples and posts, no in-shortcut calculation" do
    expect(xml).to include("https://x.test/api/health_raw")
    expect(xml).to include("is.workflow.actions.downloadurl")
    expect(xml).to include("is.workflow.actions.gettext")
    expect(xml).to include("is.workflow.actions.filter.health.quantity")
    expect(xml).not_to include("is.workflow.actions.statistics")
  end

  it "carries the version marker and metadata in the URL" do
    expect(xml).to include("client_version=#{described_class::VERSION}")
    expect(xml).to include("key=steps")
  end

  it "asks for the token at import time (no manual edit)" do
    expect(xml).to include("WFWorkflowImportQuestions")
    expect(xml).to include("Cole seu token")
    expect(xml).to include("Bearer ")
  end

  it "produces well-formed XML" do
    expect { REXML::Document.new(xml) }.not_to raise_error
  end
end
