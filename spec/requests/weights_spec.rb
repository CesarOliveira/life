require "rails_helper"

RSpec.describe "Weights", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user, height_cm: 180) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  describe "weight panel inside Saúde" do
    it "shows weight entries on the health measurements page" do
      create(:weight_entry, account: account, weight_kg: 80)
      get measurements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("80")
    end
  end

  describe "POST /weights" do
    it "creates an entry and returns to Saúde" do
      expect {
        post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "75.5" } }
      }.to change(account.weight_entries, :count).by(1)
      expect(response).to redirect_to(measurements_path(category: "health"))
    end

    it "upserts the entry for the same date" do
      create(:weight_entry, account: account, date: Date.current, weight_kg: 80)
      expect {
        post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "79" } }
      }.not_to change(account.weight_entries, :count)
      expect(account.weight_entries.find_by(date: Date.current).weight_kg.to_f).to eq(79.0)
    end

    it "rejects an invalid weight (redirects back with an alert)" do
      expect {
        post weights_path, params: { weight_entry: { date: Date.current.iso8601, weight_kg: "0" } }
      }.not_to change(account.weight_entries, :count)
      expect(response).to redirect_to(measurements_path(category: "health"))
    end
  end

  describe "DELETE /weights/:id" do
    it "removes the entry" do
      entry = create(:weight_entry, account: account)
      expect { delete weight_path(entry) }.to change(account.weight_entries, :count).by(-1)
    end
  end
end
