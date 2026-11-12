require "rails_helper"

RSpec.describe ScreenTimeChart do
  let(:today) { Date.new(2026, 11, 12) }

  it "uses one bar per day for short periods, keeping days without data" do
    chart = described_class.new({ today - 1 => 3600 }, from: today - 6, to: today)
    expect(chart).not_to be_weekly
    expect(chart.bars.size).to eq(7)
    expect(chart.bars.sum { |b| b[:days] }).to eq(1)
    expect(chart.max).to eq(3600)
  end

  it "starts at the first day with data instead of the start of the filter" do
    chart = described_class.new({ today - 9 => 600, today - 1 => 1200 }, from: today - 200, to: today)
    expect(chart.from).to eq(today - 9)
    expect(chart.bars.size).to eq(10)
  end

  it "groups long periods by week with the daily average of days that have data" do
    monday = Date.new(2026, 9, 7)
    by_date = { monday => 3600, monday + 1 => 7200, today => 600 }
    chart = described_class.new(by_date, from: today - 300, to: today)
    expect(chart).to be_weekly
    first = chart.bars.first
    expect(first).to include(from: monday, to: monday + 6, seconds: 5400, days: 2)
    expect(first[:label]).to be_present
    expect(chart.bars.count { |b| b[:days].zero? }).to be > 0
  end
end
