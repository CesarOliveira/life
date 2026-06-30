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

  describe "sleep (times -> bedtime/wake/duration)" do
    before { account }

    it "stores bedtime as the earliest start (minutes since midnight)" do
      post "/api/health_raw?key=sleep_start&period=today",
           params: "2026-06-30T23:30:00-03:00\n2026-07-01T00:15:00-03:00\n2026-07-01T06:45:00-03:00",
           headers: headers
      body = response.parsed_body
      expect(body["stored"]).to eq("sleep_bedtime")
      expect(body["value"]).to eq(23 * 60 + 30) # 1410
      expect(account.measurements.find_by(key: "sleep_bedtime").value).to eq(1410)
    end

    it "stores wake as the latest end and computes the sleep window" do
      post "/api/health_raw?key=sleep_start&period=today",
           params: "2026-06-30T23:30:00-03:00", headers: headers
      post "/api/health_raw?key=sleep_end&period=today",
           params: "2026-07-01T00:00:00-03:00\n2026-07-01T07:00:00-03:00", headers: headers

      expect(account.measurements.find_by(key: "sleep_wake").value).to eq(7 * 60) # 420
      # 07:00 - 23:30, com wrap de meia-noite = 450 min (7h30)
      expect(account.measurements.find_by(key: "sleep_minutes").value).to eq(450)
    end

    it "returns 0 samples when no parseable times are sent" do
      post "/api/health_raw?key=sleep_start&period=today", params: "", headers: headers
      expect(response.parsed_body["samples"]).to eq(0)
      expect(response.parsed_body["upserted"]).to eq(0)
    end
  end
end
