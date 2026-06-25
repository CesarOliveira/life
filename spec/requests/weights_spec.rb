require "rails_helper"

RSpec.describe "Weights", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user, height_cm: 180) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  describe "GET /weights" do
    it "renders the page with the entries" do
      create(:weight_entry, account: account, weight_kg: 80)
      get weights_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("80")
    end
  end

  describe "POST /weights" do
    it "creates an entry scoped to the account" do
      expect {
        post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "75.5" } }
      }.to change(account.weight_entries, :count).by(1)
      expect(response).to redirect_to(weights_path)
    end

    it "upserts the entry for the same date" do
      create(:weight_entry, account: account, date: Date.current, weight_kg: 80)
      expect {
        post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "79" } }
      }.not_to change(account.weight_entries, :count)
      expect(account.weight_entries.find_by(date: Date.current).weight_kg.to_f).to eq(79.0)
    end

    it "rejects an invalid weight" do
      post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "0" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /weights/:id" do
    it "removes the entry" do
      entry = create(:weight_entry, account: account)
      expect { delete weight_path(entry) }.to change(account.weight_entries, :count).by(-1)
    end
  end
end
