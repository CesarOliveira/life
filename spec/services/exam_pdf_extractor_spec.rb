require "rails_helper"

RSpec.describe ExamPdfExtractor do
  describe "#build_result" do
    let(:extractor) { described_class.new("pdf-bytes", today: Date.new(2026, 6, 1)) }

    it "normalizes rows, sanitizes keys and keeps lab reference ranges" do
      parsed = {
        "measured_on" => "2026-05-10",
        "results" => [
          { "key" => "glucose", "value" => 92, "unit" => "mg/dL", "ref_low" => 70, "ref_high" => 99 },
          { "key" => "Colesterol Total", "value" => "180", "unit" => "mg/dL" }
        ]
      }
      result = extractor.build_result(parsed)
      expect(result).to be_ok
      expect(result.measured_on).to eq(Date.new(2026, 5, 10))

      glucose = result.rows.find { |r| r[:key] == "glucose" }
      expect(glucose[:value]).to eq(92.0)
      expect(glucose[:source]).to eq("pdf")
      expect(glucose[:ref_high]).to eq(99)

      chol = result.rows.find { |r| r[:key] == "colesterol_total" }
      expect(chol[:value]).to eq(180.0)
    end

    it "falls back to today when measured_on is missing" do
      result = extractor.build_result({ "results" => [{ "key" => "glucose", "value" => 90 }] })
      expect(result.measured_on).to eq(Date.new(2026, 6, 1))
    end

    it "is no_results when no numeric rows are present" do
      result = extractor.build_result({ "results" => [{ "key" => "note", "value" => "negativo" }] })
      expect(result).not_to be_ok
      expect(result.error).to eq("no_results")
    end

    it "errors on malformed input" do
      expect(extractor.build_result(nil).error).to eq("extraction_failed")
    end
  end

  describe ".configured?" do
    it "reflects the presence of ANTHROPIC_API_KEY" do
      original = ENV["ANTHROPIC_API_KEY"]
      ENV["ANTHROPIC_API_KEY"] = "sk-test"
      expect(described_class.configured?).to be(true)
      ENV["ANTHROPIC_API_KEY"] = ""
      expect(described_class.configured?).to be(false)
    ensure
      ENV["ANTHROPIC_API_KEY"] = original
    end
  end

  describe "#call without configuration" do
    it "returns not_configured" do
      allow(described_class).to receive(:configured?).and_return(false)
      expect(described_class.new("x").call.error).to eq("not_configured")
    end
  end
end
