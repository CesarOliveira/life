require "rails_helper"

RSpec.describe "API::Usage", type: :request do
  let(:account) { create(:account) }
  let(:headers) do
    { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" }
  end

  def body(apps:, **rest)
    { device: "iphone", date: Date.current.iso8601, apps: apps, **rest }.to_json
  end

  it "rejects missing or invalid token" do
    post "/api/usage", params: body(apps: []), headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)

    post "/api/usage", params: body(apps: []),
         headers: { "Authorization" => "Bearer nope", "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "ingests per-app usage scoped to the token's account" do
    expect {
      post "/api/usage", params: body(apps: [
        { bundle_id: "com.burbn.instagram", name: "Instagram", seconds: 7620 },
        { bundle_id: "com.apple.MobileSMS", name: "Messages", seconds: 300 }
      ]), headers: headers
    }.to change(account.app_usages, :count).by(2)

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["ok"]).to be(true)
    expect(json["upserted"]).to eq(2)

    ig = account.app_usages.find_by(bundle_id: "com.burbn.instagram")
    expect(ig.seconds).to eq(7620)
    expect(ig.date).to eq(Date.current)
  end

  it "upserts the same (device,date,bundle) instead of duplicating" do
    post "/api/usage", params: body(apps: [{ bundle_id: "com.x", seconds: 100 }]), headers: headers
    expect {
      post "/api/usage", params: body(apps: [{ bundle_id: "com.x", seconds: 250 }]), headers: headers
    }.not_to change(account.app_usages, :count)
    expect(account.app_usages.find_by(bundle_id: "com.x").seconds).to eq(250)
  end

  it "skips invalid entries without failing the batch" do
    post "/api/usage", params: body(apps: [
      { bundle_id: "", seconds: 100 },
      { bundle_id: "com.ok", seconds: 100 },
      "garbage"
    ]), headers: headers

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["upserted"]).to eq(1)
    expect(json["skipped"]).to eq(2)
  end

  it "rejects an invalid payload (apps not an array)" do
    post "/api/usage", params: { device: "iphone", apps: "nope" }.to_json, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects too many entries" do
    apps = Array.new(5001) { |i| { bundle_id: "com.app#{i}", seconds: 1 } }
    post "/api/usage", params: body(apps: apps), headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
