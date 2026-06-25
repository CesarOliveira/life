require "rails_helper"

RSpec.describe ContributionGraph do
  let(:account) { create(:account) }
  let(:today) { Date.new(2026, 6, 24) }

  it "tem uma coluna por semana" do
    g = ContributionGraph.new(account, today: today, weeks: 10)
    expect(g.columns.size).to eq(10)
  end

  it "marca os dias futuros da semana atual como nil" do
    g = ContributionGraph.new(account, today: today, weeks: 4)
    last_col = g.columns.last
    expect(last_col.count(&:nil?)).to eq(6 - today.wday)
    expect(last_col.compact.last.date).to eq(today)
  end

  it "conta hábitos concluídos por dia e atribui intensidade" do
    habit = create(:habit, account: account)
    create(:habit_check, habit: habit, date: today)

    g = ContributionGraph.new(account, today: today, weeks: 4)
    cell = g.columns.flatten.compact.find { |c| c.date == today }
    expect(cell.count).to eq(1)
    expect(cell.level).to be >= 1
    expect(g.total).to eq(1)
  end

  it "ignora marcações de outras contas" do
    create(:habit_check, habit: create(:habit), date: today)
    g = ContributionGraph.new(account, today: today, weeks: 4)
    expect(g.total).to eq(0)
  end
end
