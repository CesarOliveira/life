require "rails_helper"

RSpec.describe CrossAnalysis do
  let(:account) { create(:account) }
  let(:to) { Date.new(2026, 6, 28) }
  let(:from) { to - 10 }
  let!(:habit) { create(:habit, account: account, weekdays: (0..6).to_a) } # diário, manual

  def log(date, sleep_minutes, done)
    create(:measurement, account: account, key: "sleep_minutes", value: sleep_minutes, measured_on: date, category: "health")
    create(:habit_check, habit: habit, date: date) if done
  end

  it "correlates sleep with habit adherence" do
    (0..4).each { |i| log(to - i, 8 * 60, true) }       # bom sono → feito
    (5..9).each { |i| log(to - i, 5 * 60, false) }      # pouco sono → não feito

    result = described_class.new(account, "sleep_hours", from: from, to: to).call
    expect(result.n).to eq(10)
    expect(result).to be_enough
    expect(result.above_avg).to eq(100)
    expect(result.below_avg).to eq(0)
    expect(result.correlation).to be > 0.9
    expect(result.diff).to eq(100)
  end

  it "reports not enough data below the minimum" do
    log(to, 7 * 60, true)
    result = described_class.new(account, "sleep_hours", from: from, to: to).call
    expect(result).not_to be_enough
    expect(result.n).to eq(1)
  end

  it "falls back to the first metric for an unknown key" do
    result = described_class.new(account, "bogus", from: from, to: to)
    expect(result.metric_key).to eq(CrossAnalysis::METRICS.first)
  end
end
