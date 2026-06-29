require "rails_helper"

RSpec.describe Measurement, type: :model do
  it { is_expected.to belong_to(:account) }

  it "requires key, value, measured_on" do
    expect(build(:measurement, key: nil)).not_to be_valid
    expect(build(:measurement, value: nil)).not_to be_valid
    expect(build(:measurement, measured_on: nil)).not_to be_valid
  end

  it "rejects an unknown category" do
    expect(build(:measurement, category: "bogus")).not_to be_valid
  end

  it "is unique per account/key/date" do
    account = create(:account)
    create(:measurement, account: account, key: "steps", measured_on: Date.current)
    dup = build(:measurement, account: account, key: "steps", measured_on: Date.current)
    expect(dup).not_to be_valid
  end

  describe "#out_of_range?" do
    it "is true above ref_high" do
      expect(build(:measurement, :exam, value: 120, ref_high: 99)).to be_out_of_range
    end

    it "is true below ref_low" do
      expect(build(:measurement, :exam, value: 50, ref_low: 70)).to be_out_of_range
    end

    it "is false within the range" do
      expect(build(:measurement, :exam, value: 90, ref_low: 70, ref_high: 99)).not_to be_out_of_range
    end

    it "is false without a reference range" do
      expect(build(:measurement, ref_low: nil, ref_high: nil)).not_to be_out_of_range
    end
  end

  describe ".meta / .catalog_keys" do
    it "returns catalog metadata for a known key" do
      expect(Measurement.meta("glucose")[:category]).to eq("exam")
    end

    it "lists catalog keys by category" do
      expect(Measurement.catalog_keys("exam")).to include("glucose", "hdl")
      expect(Measurement.catalog_keys("health")).to include("steps", "sleep_minutes")
    end
  end
end
