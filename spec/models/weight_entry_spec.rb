require "rails_helper"

RSpec.describe WeightEntry, type: :model do
  it { is_expected.to belong_to(:account) }

  it "requires date and weight" do
    expect(build(:weight_entry, date: nil)).not_to be_valid
    expect(build(:weight_entry, weight_kg: nil)).not_to be_valid
  end

  it "rejects non-positive weight" do
    expect(build(:weight_entry, weight_kg: 0)).not_to be_valid
  end

  it "is unique per account and date" do
    e = create(:weight_entry)
    expect(build(:weight_entry, account: e.account, date: e.date)).not_to be_valid
  end

  describe "#bmi" do
    it "computes from the account height" do
      account = create(:account, height_cm: 180)
      entry = create(:weight_entry, account: account, weight_kg: 81.0)
      expect(entry.bmi).to eq(25.0) # 81 / 1.8²
    end

    it "is nil without height" do
      account = create(:account, height_cm: nil)
      expect(create(:weight_entry, account: account).bmi).to be_nil
    end
  end

  describe "#bmi_category" do
    def category_for(weight, height)
      account = create(:account, height_cm: height)
      create(:weight_entry, account: account, weight_kg: weight).bmi_category
    end

    it "classifies by the WHO ranges" do
      expect(category_for(50, 180)).to eq(:underweight)
      expect(category_for(70, 180)).to eq(:normal)
      expect(category_for(85, 180)).to eq(:overweight)
      expect(category_for(100, 180)).to eq(:obese)
    end
  end
end
