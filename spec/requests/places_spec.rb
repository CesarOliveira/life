require "rails_helper"

RSpec.describe "Places", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }
  let(:gym) { { latitude: -21.4112, longitude: -48.5031 } }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "shows the day timeline and the manage page" do
    Places::Ingest.new(account, source: "google").call([{ external_id: "g", arrived_at: 2.hours.ago.iso8601, departed_at: 1.hour.ago.iso8601, **gym }])
    get places_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("places.unnamed"), "places-map")

    get manage_places_path
    expect(response.body).to include(I18n.t("places.import_title"), I18n.t("places.suggestions_title"))
  end

  it "imports visits extracted in the browser and names a place" do
    post import_places_path, params: { visits: [{ external_id: "google:x:1", arrived_at: 3.hours.ago.iso8601, departed_at: 2.hours.ago.iso8601, **gym }] }, as: :json
    expect(response.parsed_body).to include("created" => 1)

    post places_path, params: { place: { name: "Academia", **gym } }
    expect(account.visits.first.reload.place.name).to eq("Academia")
  end

  it "deletes the location history" do
    Places::Ingest.new(account, source: "google").call([{ external_id: "g", arrived_at: 2.hours.ago.iso8601, **gym }])
    delete places_history_path
    expect(account.visits.count).to eq(0)
  end

  it "never shows another account's visits" do
    other = create(:account)
    Places::Ingest.new(other, source: "google").call([{ external_id: "o", arrived_at: 2.hours.ago.iso8601, departed_at: 1.hour.ago.iso8601, **gym }])
    get places_path
    expect(response.body).not_to include("-21.4112")
    expect(account.visits.count).to eq(0)
  end
end
