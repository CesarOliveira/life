require "rails_helper"

RSpec.describe "API::Visits", type: :request do
  let(:account) { create(:account) }
  let(:headers) { { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" } }

  it "requires the token and ingests iPhone visits idempotently" do
    payload = { visits: [{ external_id: "clv-1", arrived_at: 2.hours.ago.iso8601, latitude: -21.4112, longitude: -48.5031, accuracy_m: 40 }] }
    post "/api/visits", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)

    post "/api/visits", params: payload.to_json, headers: headers
    expect(response.parsed_body).to include("ok" => true, "created" => 1)

    payload[:visits][0][:departed_at] = 1.hour.ago.iso8601
    post "/api/visits", params: payload.to_json, headers: headers
    expect(response.parsed_body).to include("updated" => 1)
    expect(account.visits.sole).to have_attributes(source: "iphone", accuracy_m: 40)
  end
end
