require "rails_helper"

RSpec.describe "API::HealthRaw", type: :request do
  let(:account) { create(:account, api_token: "tok_raw_123") }
  let(:headers) { { "Authorization" => "Bearer tok_raw_123", "Content-Type" => "text/plain" } }

  it "rejects without a valid token" do
    post "/api/health_raw?key=steps&period=today", params: "100", headers: { "Content-Type" => "text/plain" }
    expect(response).to have_http_status(:unauthorized)
  end

  let(:yesterday) { (Date.current - 1).iso8601 }

  it "stores yesterday's step total (single pre-aggregated number) and echoes a preview" do
    account
    post "/api/health_raw?key=steps&period=yesterday&client_version=v12",
         params: "8.021", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["ok"]).to be(true)
    expect(body["key"]).to eq("steps")
    expect(body["days"]).to eq(1)
    expect(body["stored"][yesterday]["value"]).to eq(8021.0)
    expect(body["client_version"]).to eq("v12")
    expect(body["raw_preview"]).to include("8.021")

    m = account.measurements.find_by(key: "steps", measured_on: Date.current - 1)
    expect(m.value).to eq(8021)
    expect(m.unit).to eq("passos")
  end

  it "buckets 'value|date' sample lines by calendar day (sum per day)" do
    account
    two_days_ago = (Date.current - 2)
    post "/api/health_raw?key=steps&period=yesterday",
         params: "100|#{yesterday}, 08:00\n50|#{yesterday}, 09:00\n7|#{two_days_ago.iso8601}, 22:00",
         headers: headers

    expect(account.measurements.find_by(key: "steps", measured_on: Date.current - 1).value).to eq(150)
    expect(account.measurements.find_by(key: "steps", measured_on: two_days_ago).value).to eq(7)
  end

  it "never stores today (partial day is dropped)" do
    account
    post "/api/health_raw?key=steps&period=today", params: "1234", headers: headers
    expect(response.parsed_body["days"]).to eq(0)
    expect(account.measurements.where(key: "steps")).to be_empty
  end

  it "averages resting heart-rate for the day" do
    account
    post "/api/health_raw?key=resting_hr&period=yesterday",
         params: "62", headers: headers
    expect(account.measurements.find_by(key: "resting_hr", measured_on: Date.current - 1).value).to eq(62.0)
  end

  it "is idempotent for the same key and day" do
    account
    2.times do
      post "/api/health_raw?key=steps&period=yesterday", params: "300", headers: headers
    end
    expect(account.measurements.where(key: "steps").count).to eq(1)
  end

  it "ignores units/text around the number" do
    account
    post "/api/health_raw?key=steps&period=yesterday",
         params: "8.021 contagem", headers: headers
    expect(account.measurements.find_by(key: "steps", measured_on: Date.current - 1).value).to eq(8021.0)
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

    it "parses the pt-BR date format the iPhone sends (incl. non-English months)" do
      post "/api/health_raw?key=sleep_start&period=today",
           params: "28 de fev. de 2026, 23:50\n01 de mar. de 2026, 06:10", headers: headers
      body = response.parsed_body
      expect(body["samples"]).to eq(2)
      # menor início (absoluto) = 28/02 23:50 -> 23*60+50 = 1430
      expect(body["value"]).to eq(1430)
    end
  end
end
