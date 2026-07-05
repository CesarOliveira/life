require "rails_helper"

RSpec.describe Connectors::GithubSync do
  let(:account) { create(:account) }
  let(:connector) { Connector.create!(account: account, kind: "github", access_token: "tok") }

  let(:fake_client) do
    Class.new do
      def self.contribution_days(_token, from:, to:)
        [{ date: to, count: 7 }, { date: to - 1, count: 0 }]
      end
    end
  end

  it "upserts daily measurements and marks the connector synced" do
    count = described_class.new(connector, client: fake_client).call(from: Date.current - 1, to: Date.current)
    expect(count).to eq(2)

    m = account.measurements.find_by(key: "github_contributions", measured_on: Date.current)
    expect(m.value).to eq(7)
    expect(m.category).to eq("productivity")
    expect(m.source).to eq("connector")
    expect(connector.reload.last_points).to eq(2)
    expect(connector.last_synced_at).to be_present
  end

  it "is idempotent (re-sync overwrites, não duplica)" do
    2.times { described_class.new(connector, client: fake_client).call(from: Date.current - 1, to: Date.current) }
    expect(account.measurements.where(key: "github_contributions").count).to eq(2)
  end

  it "evaluates automatic habits on synced dates" do
    habit = create(:habit, account: account, auto: true, metric_key: "github_contributions",
                           comparator: "gte", threshold_value: 1)
    described_class.new(connector, client: fake_client).call(from: Date.current - 1, to: Date.current)
    expect(habit.habit_checks.exists?(date: Date.current)).to be(true)   # 7 >= 1
    expect(habit.habit_checks.exists?(date: Date.current - 1)).to be(false) # 0 < 1
  end

  it "marks the connector on error without raising" do
    broken = Class.new { def self.contribution_days(*, **) = raise("api down") }
    expect(described_class.new(connector, client: broken).call).to eq(0)
    expect(connector.reload.status).to eq("error")
    expect(connector.last_error).to include("api down")
  end
end
