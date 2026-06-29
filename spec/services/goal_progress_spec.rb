require "rails_helper"

RSpec.describe GoalProgress do
  let(:account) { create(:account) }

  describe "weight goal (losing weight)" do
    let(:goal) { create(:goal, account: account, metric_key: "weight", start_value: 90, target_value: 80) }

    it "computes percentage of the way from start to target" do
      create(:weight_entry, account: account, date: Date.current - 2, weight_kg: 90)
      create(:weight_entry, account: account, date: Date.current, weight_kg: 85) # metade do caminho
      progress = described_class.new(goal)
      expect(progress.current_value).to eq(85)
      expect(progress.progress_pct).to eq(50)
      expect(progress).not_to be_achieved
      expect(progress.remaining).to eq(5)
    end

    it "is achieved when the target is reached" do
      create(:weight_entry, account: account, date: Date.current - 1, weight_kg: 90)
      create(:weight_entry, account: account, date: Date.current, weight_kg: 79)
      progress = described_class.new(goal)
      expect(progress).to be_achieved
      expect(progress.progress_pct).to eq(100)
      expect(progress.achieved_on).to eq(Date.current)
    end
  end

  describe "measurement goal (increasing)" do
    let(:goal) { create(:goal, :exam, account: account) } # vitamin_d 20 -> 40

    it "tracks progress upward" do
      create(:measurement, account: account, key: "vitamin_d", value: 30, measured_on: Date.current, category: "exam")
      progress = described_class.new(goal)
      expect(progress.direction).to eq(:up)
      expect(progress.progress_pct).to eq(50)
    end
  end

  describe "without data" do
    let(:goal) { create(:goal, account: account, metric_key: "weight", start_value: nil, target_value: 80) }

    it "reports no data" do
      expect(described_class.new(goal).data?).to be(false)
      expect(described_class.new(goal).progress_pct).to eq(0)
    end
  end
end
