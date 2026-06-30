require "rails_helper"
require "rexml/document"

RSpec.describe HealthShortcutBuilder do
  subject(:xml) { described_class.new(token: "TOK123", endpoint: "https://x.test/api/metrics").plist }

  it "embeds the token, endpoint and the download action" do
    expect(xml).to include("Bearer TOK123")
    expect(xml).to include("https://x.test/api/metrics")
    expect(xml).to include("is.workflow.actions.downloadurl")
    expect(xml).to include("is.workflow.actions.gettext")
  end

  it "produces well-formed XML" do
    expect { REXML::Document.new(xml) }.not_to raise_error
  end
end
