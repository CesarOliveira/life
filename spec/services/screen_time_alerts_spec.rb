require "rails_helper"

RSpec.describe ScreenTimeAlerts do
  subject(:alerts) { described_class.new(account) }

  let(:account) { create(:account) }
  let(:today) { Date.current }

  let!(:habit) do
    create(:habit, account: account, name: "Menos redes", auto: true, metric_key: "social_apps",
                   comparator: "lte", threshold_value: 2, app_bundle_ids: %w[Instagram Facebook])
  end

  def usage(bundle, seconds)
    create(:app_usage, account: account, bundle_id: bundle, date: today, seconds: seconds)
  end

  describe "#snapshot" do
    it "returns the day's hours per habit id, counting only the chosen apps" do
      usage("Instagram", 3600)
      usage("WhatsApp", 7200) # fora do hábito
      expect(alerts.snapshot(today)).to eq(habit.id => 1.0)
    end
  end

  describe "#messages" do
    it "alerts when this sync crosses the threshold (antes ≤ limite < agora)" do
      usage("Instagram", (2.5 * 3600).to_i)
      msgs = alerts.messages(today, previous: { habit.id => 1.5 })
      expect(msgs).to eq(["Menos redes: 2h 30m hoje (limite 2h)"])
    end

    it "does not repeat once already over in the previous sync" do
      usage("Instagram", (2.5 * 3600).to_i)
      expect(alerts.messages(today, previous: { habit.id => 2.4 })).to be_empty
    end

    it "stays silent while under the threshold" do
      usage("Instagram", 3600)
      expect(alerts.messages(today, previous: { habit.id => 0.5 })).to be_empty
    end

    it "alerts on the first sync of the day when already over (previous vazio)" do
      usage("Instagram", 3 * 3600)
      expect(alerts.messages(today, previous: {})).to eq(["Menos redes: 3h hoje (limite 2h)"])
    end

    it "ignores gte and inactive habits" do
      habit.update!(active: false)
      create(:habit, account: account, auto: true, metric_key: "screen_time_total",
                     comparator: "gte", threshold_value: 1)
      usage("Instagram", 3 * 3600)
      expect(alerts.messages(today, previous: {})).to be_empty
    end
  end
end
