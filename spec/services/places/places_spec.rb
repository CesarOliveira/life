require "rails_helper"

RSpec.describe "Places services" do
  let(:account) { create(:account) }
  let(:day) { Date.new(2026, 11, 19) }
  let(:home) { { latitude: -21.40424, longitude: -48.51087 } }
  let(:gym) { { latitude: -21.41120, longitude: -48.50310 } }

  def at(hour, min = 0, date = day) = date.in_time_zone.change(hour: hour, min: min).iso8601

  def ingest(items, source: "google") = Places::Ingest.new(account, source: source).call(items)

  it "stores visits with encrypted coordinates, idempotent by external_id" do
    r = ingest([{ external_id: "a", arrived_at: at(8), departed_at: at(9), **gym }])
    expect(r.to_h).to include(created: 1)
    raw = Visit.connection.select_value("SELECT latitude FROM visits LIMIT 1")
    expect(raw).not_to include("-21.4112")
    expect(account.visits.first.lat).to eq(-21.4112)

    r = ingest([{ external_id: "a", arrived_at: at(8), departed_at: at(9, 30), **gym }])
    expect(r.to_h).to include(created: 0, updated: 1)
    expect(account.visits.count).to eq(1)
  end

  it "skips invalid items (no coordinate, departure before arrival, too long)" do
    r = ingest([{ arrived_at: at(8) }, { arrived_at: at(9), departed_at: at(8), **gym },
                { arrived_at: at(8), departed_at: (day + 40).iso8601, **gym }])
    expect(r.to_h).to include(created: 0, skipped: 3)
  end

  it "assigns visits to the nearest named place within its radius and suggests unnamed clusters" do
    ingest([{ external_id: "h1", arrived_at: at(0), departed_at: at(7), hint: "HOME", **home },
            { external_id: "g1", arrived_at: at(8), departed_at: at(9), **gym }])
    suggestion = Places::Suggestions.new(account).call.first
    expect(suggestion.suggested_name).to eq("Casa")

    account.places.create!(name: "Academia", **gym)
    expect(Places::Matcher.new(account).assign_unassigned).to eq(1)
    expect(account.visits.find_by(external_id: "g1").place.name).to eq("Academia")
    expect(account.visits.find_by(external_id: "h1").place).to be_nil
  end

  it "builds a day timeline clipped to the local day with totals per place" do
    account.places.create!(name: "Casa", **home)
    ingest([{ external_id: "n", arrived_at: at(22, 0, day - 1), departed_at: at(7), **home },
            { external_id: "g", arrived_at: at(8), departed_at: at(9, 30), **gym }])
    timeline = Places::Timeline.new(account, day)
    expect(timeline.entries.map(&:seconds)).to eq([7.hours, 90.minutes])
    expect(timeline.entries.first.starts_before).to be(true)
    expect(timeline.totals).to eq([["Casa", 7.hours], [I18n.t("places.unnamed"), 90.minutes]])
  end

  it "checks a place_minutes habit automatically" do
    gym_place = account.places.create!(name: "Academia", **gym)
    habit = account.habits.create!(name: "Academia 45 min", color: "emerald", auto: true, metric_key: "place_minutes",
                                   comparator: "gte", threshold_value: 45, place_ids: [gym_place.id],
                                   habit_category: account.habit_categories.first || create(:habit_category, account: account))
    travel_to(day + 1) do
      ingest([{ external_id: "g", arrived_at: at(8), departed_at: at(9), **gym }], source: "iphone")
    end
    expect(habit.habit_checks.pluck(:date)).to eq([day])
  end
end

RSpec.describe Mcp::Tools do
  it "reports time per named place and the visits timeline without coordinates" do
    account = create(:account)
    gym = { latitude: -21.4112, longitude: -48.5031 }
    account.places.create!(name: "Academia", **gym)
    day = Date.current - 1
    Places::Ingest.new(account, source: "google").call([{ external_id: "g", arrived_at: day.in_time_zone.change(hour: 8).iso8601,
                                                         departed_at: day.in_time_zone.change(hour: 9).iso8601, **gym }])
    tools = described_class.new(account)
    places = tools.call("get_places", {})
    expect(places[:places]).to eq([{ name: "Academia", hours: 1.0, visits: 1, days_with_visit: 1 }])
    visits = tools.call("get_place_visits", { "from" => day.iso8601, "to" => day.iso8601 })
    expect(visits[:visits].sole).to include(minutes: 60, place: "Academia")
    expect(visits.to_json).not_to include("-21.4112")
  end
end
