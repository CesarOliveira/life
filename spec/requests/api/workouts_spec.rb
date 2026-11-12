require "rails_helper"

RSpec.describe "API::Workouts", type: :request do
  let(:account) { create(:account) }
  let(:headers) { { "Authorization" => "Bearer #{account.api_token}", "CONTENT_TYPE" => "application/json" } }

  def workout(**over)
    start = (Time.zone.now - 1.day).change(hour: 7)
    { uuid: "A1", activity: "running", start: start.iso8601, end: (start + 40.minutes).iso8601, duration: 2400,
      energy_kcal: 410.4, distance_m: 6000, avg_hr: 148.2, max_hr: 171, source: "Apple Watch" }.merge(over)
  end

  it "rejects an invalid token" do
    post "/api/workouts", params: { workouts: [] }.to_json, headers: headers.merge("Authorization" => "Bearer nope")
    expect(response).to have_http_status(:unauthorized)
  end

  it "stores workouts, is idempotent by uuid and logs the ingestion" do
    body = { workouts: [workout, workout(uuid: "B2", activity: "strength_training", distance_m: nil)] }.to_json
    expect { post "/api/workouts", params: body, headers: headers }
      .to change(account.workouts, :count).by(2).and change(IngestionLog, :count).by(1)

    run = account.workouts.find_by(uuid: "A1")
    expect(run).to have_attributes(activity: "running", duration_seconds: 2400, date: Date.current - 1, source: "Apple Watch")
    expect(run.pace_label).to eq("6:40 /km")
    expect(account.workouts.find_by(uuid: "B2").distance_km).to be_nil

    updated = { workouts: [workout(duration: 2500)] }.to_json
    expect { post "/api/workouts", params: updated, headers: headers }.not_to change(account.workouts, :count)
    expect(run.reload.duration_seconds).to eq(2500)
  end

  it "skips entries without uuid or start" do
    post "/api/workouts", params: { workouts: [workout(uuid: ""), workout(uuid: "C3", start: "nope")] }.to_json, headers: headers
    expect(JSON.parse(response.body)).to include("upserted" => 0, "skipped" => 2)
  end
end
