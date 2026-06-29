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

  it "falls back to the app name as bundle_id when bundle_id is absent (iPhone Shortcut)" do
    post "/api/usage", params: body(apps: [{ name: "Instagram", minutes: 127 }]), headers: headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["upserted"]).to eq(1)

    row = account.app_usages.find_by(bundle_id: "Instagram")
    expect(row).to be_present
    expect(row.name).to eq("Instagram")
    expect(row.seconds).to eq(127 * 60)
  end

  it "parses the iPhone duration text (e.g. '2h 36min') into seconds" do
    post "/api/usage", params: body(apps: [
      { name: "Instagram", duration: "2h 36min" },
      { name: "WhatsApp", duration: "22min" },
      { name: "Waze", duration: "1h" }
    ]), headers: headers
    expect(response).to have_http_status(:ok)
    expect(account.app_usages.find_by(bundle_id: "Instagram").seconds).to eq(2 * 3600 + 36 * 60)
    expect(account.app_usages.find_by(bundle_id: "WhatsApp").seconds).to eq(22 * 60)
    expect(account.app_usages.find_by(bundle_id: "Waze").seconds).to eq(3600)
  end

  it "parses the pt-BR seconds text the iPhone sends (e.g. '9.909,861 seg')" do
    post "/api/usage", params: body(apps: [
      { name: "Instagram", duration: "9.909,861 seg" },
      { name: "Chrome", duration: "1.882,599 seg" }
    ]), headers: headers
    expect(account.app_usages.find_by(bundle_id: "Instagram").seconds).to eq(9910)
    expect(account.app_usages.find_by(bundle_id: "Chrome").seconds).to eq(1883)
  end

  it "accepts apps as a JSON string (Shortcuts may stringify the list)" do
    post "/api/usage",
         params: { device: "iphone", date: Date.current.iso8601,
                   apps: [{ name: "Instagram", duration: "1h" }].to_json }.to_json,
         headers: headers
    expect(response).to have_http_status(:ok)
    expect(account.app_usages.find_by(bundle_id: "Instagram").seconds).to eq(3600)
  end

  it "resolves period 'yesterday' to yesterday's date (no date field needed)" do
    post "/api/usage",
         params: { device: "iphone", period: "yesterday",
                   apps: [{ name: "Instagram", duration: "1h" }] }.to_json,
         headers: headers
    expect(account.app_usages.find_by(bundle_id: "Instagram").date).to eq(Date.current - 1)
  end

  it "accepts minutes (fractional) as an alternative to seconds" do
    post "/api/usage", params: body(apps: [{ bundle_id: "com.x", minutes: 1.5 }]), headers: headers
    expect(account.app_usages.find_by(bundle_id: "com.x").seconds).to eq(90)
  end

  it "prefers seconds over minutes when both are sent" do
    post "/api/usage", params: body(apps: [{ bundle_id: "com.x", seconds: 42, minutes: 999 }]), headers: headers
    expect(account.app_usages.find_by(bundle_id: "com.x").seconds).to eq(42)
  end

  it "skips an entry with neither bundle_id nor name" do
    post "/api/usage", params: body(apps: [{ minutes: 10 }, { name: "Ok", minutes: 5 }]), headers: headers
    json = JSON.parse(response.body)
    expect(json["upserted"]).to eq(1)
    expect(json["skipped"]).to eq(1)
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
