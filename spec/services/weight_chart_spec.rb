require "rails_helper"

RSpec.describe WeightChart do
  let(:account) { create(:account) }

  it "is empty when there are no entries" do
    chart = WeightChart.new([])
    expect(chart.any?).to be(false)
    expect(chart.points).to eq([])
  end

  it "produces one point per entry in chronological order" do
    older = create(:weight_entry, account: account, date: Date.new(2026, 6, 20), weight_kg: 80)
    newer = create(:weight_entry, account: account, date: Date.new(2026, 6, 24), weight_kg: 78)

    chart = WeightChart.new([newer, older]) # passa fora de ordem
    pts = chart.points

    expect(pts.size).to eq(2)
    expect(pts.map { |p| p.weight.to_f }).to eq([80.0, 78.0])
    expect(pts.first.x).to be < pts.last.x
  end

  it "reports min and max weights" do
    create(:weight_entry, account: account, date: Date.new(2026, 6, 20), weight_kg: 80)
    create(:weight_entry, account: account, date: Date.new(2026, 6, 24), weight_kg: 78)

    chart = WeightChart.new(account.weight_entries.to_a)
    expect(chart.min_weight.to_f).to eq(78.0)
    expect(chart.max_weight.to_f).to eq(80.0)
  end
end
