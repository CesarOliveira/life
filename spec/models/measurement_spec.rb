# == Schema Information
#
# Table name: measurements
#
#  id          :bigint           not null, primary key
#  category    :string           default("health"), not null
#  key         :string           not null
#  measured_on :date             not null
#  ref_high    :decimal(12, 3)
#  ref_low     :decimal(12, 3)
#  source      :string           default("manual"), not null
#  unit        :string
#  value       :decimal(12, 3)   not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  idx_measurements_unique                        (account_id,key,measured_on) UNIQUE
#  index_measurements_on_account_id               (account_id)
#  index_measurements_on_account_id_and_category  (account_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
      expect(Measurement.meta("steps")[:category]).to eq("health")
    end

    it "lists catalog keys by category (health only; exams live in ExamType)" do
      expect(Measurement.catalog_keys("health")).to include("steps", "sleep_minutes")
      expect(Measurement.catalog_keys("exam")).to be_empty
    end
  end
end
