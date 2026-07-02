require "rails_helper"

RSpec.describe Goal, type: :model do
  it { is_expected.to belong_to(:account) }

  it "requires name, metric_key and target_value" do
    expect(build(:goal, name: nil)).not_to be_valid
    expect(build(:goal, metric_key: nil)).not_to be_valid
    expect(build(:goal, target_value: nil)).not_to be_valid
  end

  it "rejects an unknown metric_key" do
    expect(build(:goal, metric_key: "bogus")).not_to be_valid
  end

  describe "#unit / #metric_label" do
    it "uses kg for weight" do
      expect(build(:goal, metric_key: "weight").unit).to eq("kg")
    end

    it "uses the catalog unit for a health metric" do
      expect(build(:goal, metric_key: "steps").unit).to eq("passos")
    end

    it "uses the latest result unit for an exam metric" do
      goal = create(:goal, :exam)
      create(:exam_result, account: goal.account, exam_type: ExamType.find_by(key: "vitamin_d"), value: 30, unit: "ng/mL")
      expect(goal.unit).to eq("ng/mL")
      expect(goal.metric_label).to eq("Vitamina D (25-OH)")
    end
  end
end
