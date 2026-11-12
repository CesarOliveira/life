require "rails_helper"

RSpec.describe "API::Metrics", type: :request do
  let(:account) { create(:account) }
  let(:headers) do
    { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" }
  end

  def body(metrics:, **rest)
    { date: Date.current.iso8601, metrics: metrics, **rest }.to_json
  end

  it "rejects an invalid token" do
    post "/api/metrics", params: body(metrics: []),
         headers: { "Authorization" => "Bearer nope", "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "ingests health metrics and fills unit/category from the catalog" do
    expect {
      post "/api/metrics", params: body(metrics: [
        { key: "sleep_minutes", value: 437 },
        { key: "steps", value: 8021 }
      ]), headers: headers
    }.to change(account.measurements, :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["upserted"]).to eq(2)

    sleep = account.measurements.find_by(key: "sleep_minutes")
    expect(sleep.value).to eq(437)
    expect(sleep.unit).to eq("min")
    expect(sleep.category).to eq("health")
    expect(sleep.source).to eq("api")
  end

  it "is idempotent: re-sending the same day overwrites instead of duplicating" do
    post "/api/metrics", params: body(metrics: [{ key: "steps", value: 5000 }]), headers: headers
    expect {
      post "/api/metrics", params: body(metrics: [{ key: "steps", value: 9000 }]), headers: headers
    }.not_to change(account.measurements, :count)
    expect(account.measurements.find_by(key: "steps").value).to eq(9000)
  end

  it "parses pt-BR numeric text and resolves period" do
    post "/api/metrics", params: { period: "yesterday", metrics: [{ key: "active_energy", value: "1.234,5" }] }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    row = account.measurements.find_by(key: "active_energy")
    expect(row.value).to eq(1234.5)
    expect(row.measured_on).to eq(Date.current - 1)
  end

  it "accepts metrics as a JSON string (Shortcuts serialization)" do
    body = { date: Date.current.iso8601, metrics: [{ key: "steps", value: 8021 }].to_json }.to_json
    post "/api/metrics", params: body, headers: headers
    expect(response).to have_http_status(:ok)
    expect(account.measurements.find_by(key: "steps").value).to eq(8021)
  end

  it "accepts metrics as newline-delimited JSON objects" do
    lines = [{ key: "steps", value: 5000 }, { key: "sleep_minutes", value: 420 }].map(&:to_json).join("\n")
    post "/api/metrics", params: { date: Date.current.iso8601, metrics: lines }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["upserted"]).to eq(2)
  end

  it "skips entries without a numeric value" do
    post "/api/metrics", params: body(metrics: [{ key: "steps", value: "abc" }, { key: "glucose", value: 90 }]), headers: headers
    json = JSON.parse(response.body)
    expect(json["upserted"]).to eq(1)
    expect(json["skipped"]).to eq(1)
  end

  it "ingests an Apple Watch batch from the native app across days and logs it" do
    yesterday = (Date.current - 1).iso8601
    payload = { client_version: "app-0.2.0", metrics: [
      { key: "hrv", value: 48.2, date: yesterday },
      { key: "exercise_minutes", value: 42, date: yesterday },
      { key: "sleep_deep_minutes", value: 61, date: Date.current.iso8601 },
      { key: "spo2", value: 96.5, date: yesterday }
    ] }.to_json

    expect { post "/api/metrics", params: payload, headers: headers }
      .to change(account.measurements, :count).by(4).and change(IngestionLog, :count).by(1)

    hrv = account.measurements.find_by(key: "hrv")
    expect(hrv).to have_attributes(unit: "ms", category: "health", measured_on: Date.current - 1)
    expect(account.measurements.find_by(key: "sleep_deep_minutes").display_value).to eq("1h 1min")
    expect(IngestionLog.last).to have_attributes(endpoint: "metrics", status: 200)
    expect(IngestionLog.last.result).to include("upserted" => 4, "days" => 2)

    # reenvio do mesmo lote sobrescreve, não duplica
    expect { post "/api/metrics", params: payload, headers: headers }.not_to change(account.measurements, :count)
  end
end
