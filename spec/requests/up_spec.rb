require "rails_helper"

# Health checks (/up, /up/databases) e o root público — portados do Minitest.
RSpec.describe "Health & root", type: :request do
  it "serves the liveness check" do
    get up_path
    expect(response).to have_http_status(:ok)
  end

  it "serves the databases readiness check (Redis + Postgres)" do
    get up_databases_path
    expect(response).to have_http_status(:ok)
  end

  it "renders the login page at root when signed out" do
    get root_path
    expect(response).to have_http_status(:ok)
  end
end
