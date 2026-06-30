require "rails_helper"

RSpec.describe "API::HealthRaw", type: :request do
  let(:account) { create(:account, api_token: "tok_raw_123") }
  let(:headers) { { "Authorization" => "Bearer tok_raw_123", "Content-Type" => "text/plain" } }

  it "rejects without a valid token" do
    post "/api/health_raw?key=steps&period=today", params: "100", headers: { "Content-Type" => "text/plain" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "sums raw step samples (no calc in client) and echoes a preview" do
    account
    post "/api/health_raw?key=steps&period=today&client_version=v5",
         params: "3.021\n2.500\n2.500", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["ok"]).to be(true)
    expect(body["key"]).to eq("steps")
    expect(body["samples"]).to eq(3)
    expect(body["value"]).to eq(8021.0)
    expect(body["upserted"]).to eq(1)
    expect(body["client_version"]).to eq("v5")
    expect(body["raw_preview"]).to include("3.021")

    m = account.measurements.find_by(key: "steps")
    expect(m.value).to eq(8021)
    expect(m.unit).to eq("passos")
  end

  it "averages resting heart-rate samples" do
    account
    post "/api/health_raw?key=resting_hr&period=today",
         params: "60\n62\n64", headers: headers

    expect(response.parsed_body["value"]).to eq(62.0)
  end

  it "is idempotent for the same key and day" do
    account
    2.times do
      post "/api/health_raw?key=steps&period=today", params: "100\n200", headers: headers
    end
    expect(account.measurements.where(key: "steps").count).to eq(1)
  end

  it "ignores units/text and parses one number per line" do
    account
    post "/api/health_raw?key=steps&period=today",
         params: "5.000 contagem\n3.021 contagem", headers: headers
    expect(response.parsed_body["value"]).to eq(8021.0)
  end
end
