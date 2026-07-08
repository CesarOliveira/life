require "rails_helper"

RSpec.describe "Ingestion logging", type: :request do
  let(:account) { create(:account) }
  let(:headers) { { "Authorization" => "Bearer #{account.api_token}", "Content-Type" => "text/plain" } }

  before { account.regenerate_api_token }
  let(:auth) { { "Authorization" => "Bearer #{account.reload.api_token}", "Content-Type" => "text/plain" } }

  it "logs a health_raw ingestion with raw body, query and result" do
    expect {
      post "/api/health_raw?key=steps&period=yesterday&client_version=v11", params: "1234\n5678", headers: auth
    }.to change(IngestionLog, :count).by(1)

    log = IngestionLog.last
    expect(log.endpoint).to eq("health_raw")
    expect(log.account).to eq(account)
    expect(log.query["key"]).to eq("steps")
    expect(log.query["period"]).to eq("yesterday")
    expect(log.client_version).to eq("v11")
    expect(log.status).to eq(200)
    expect(log.raw_body).to include("1234")
    expect(log.result["key"]).to eq("steps")
    expect(log.result["measured_on"]).to eq((Date.current - 1).iso8601)
  end

  it "logs a usage_raw ingestion" do
    expect {
      post "/api/usage_raw?period=yesterday&device=iphone&client_version=v11",
           params: "Instagram (2h 36min)", headers: auth
    }.to change(IngestionLog, :count).by(1)
    expect(IngestionLog.last.endpoint).to eq("usage_raw")
  end

  it "logs even when the payload is rejected (invalid key)" do
    expect {
      post "/api/health_raw?key=&period=yesterday", params: "1", headers: auth
    }.to change(IngestionLog, :count).by(1)
    expect(IngestionLog.last.status).to eq(422)
  end
end
