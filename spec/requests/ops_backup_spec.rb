require "rails_helper"

RSpec.describe "Ops backup", type: :request do
  let(:secret) { "s" * 40 }

  around do |example|
    previous = ENV.fetch("BACKUP_TOKEN", nil)
    example.run
  ensure
    ENV["BACKUP_TOKEN"] = previous
  end

  it "does not exist while BACKUP_TOKEN is unset or too short" do
    ENV["BACKUP_TOKEN"] = nil
    get "/ops/backup", headers: { "Authorization" => "Bearer #{secret}" }
    expect(response).to have_http_status(:not_found)

    ENV["BACKUP_TOKEN"] = "curto"
    get "/ops/backup", headers: { "Authorization" => "Bearer curto" }
    expect(response).to have_http_status(:not_found)
  end

  it "rejects a wrong or missing token, including account tokens" do
    ENV["BACKUP_TOKEN"] = secret
    account = create(:account)
    [nil, "Bearer errado", "Bearer #{account.api_token}"].each do |header|
      get "/ops/backup", headers: { "Authorization" => header }.compact
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "streams the pg_dump archive with the right token and never passes the password on the command line" do
    ENV["BACKUP_TOKEN"] = secret
    ok = instance_double(Process::Status, success?: true, exitstatus: 0)
    expect(Open3).to receive(:capture3) do |env, *command, **|
      expect(env).to include("PGDATABASE", "PGPASSWORD")
      expect(command).to eq(["pg_dump", "--format=custom", "--no-owner", "--no-privileges"])
      ["PGDMP\x01binario", "", ok]
    end

    get "/ops/backup", headers: { "Authorization" => "Bearer #{secret}" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to start_with("PGDMP")
    expect(response.headers["Content-Disposition"]).to include("life-", ".dump")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "fails closed when pg_dump fails" do
    ENV["BACKUP_TOKEN"] = secret
    allow(Open3).to receive(:capture3).and_return(["", "connection refused", instance_double(Process::Status, success?: false, exitstatus: 1)])
    get "/ops/backup", headers: { "Authorization" => "Bearer #{secret}" }
    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to be_empty
  end
end
