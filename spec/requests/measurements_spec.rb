require "rails_helper"

RSpec.describe "Measurements", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  describe "GET /measurements" do
    it "shows health signals by default" do
      create(:measurement, account: account, key: "steps", value: 9000)
      get measurements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("measurements.keys.steps"))
    end

    it "shows exams when filtered" do
      create(:measurement, :exam, account: account)
      get measurements_path(category: "exam")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("measurements.keys.glucose"))
    end
  end

  describe "POST /measurements" do
    it "creates an exam and fills the reference range from the catalog" do
      expect {
        post measurements_path, params: { measurement: { key: "glucose", value: "92", category: "exam", measured_on: Date.current.iso8601 } }
      }.to change(account.measurements, :count).by(1)

      m = account.measurements.last
      expect(m.category).to eq("exam")
      expect(m.ref_high).to eq(99)
      expect(m.unit).to eq("mg/dL")
    end

    it "overwrites the same key/date instead of duplicating" do
      post measurements_path, params: { measurement: { key: "steps", value: "5000", category: "health", measured_on: Date.current.iso8601 } }
      expect {
        post measurements_path, params: { measurement: { key: "steps", value: "8000", category: "health", measured_on: Date.current.iso8601 } }
      }.not_to change(account.measurements, :count)
      expect(account.measurements.find_by(key: "steps").value).to eq(8000)
    end
  end

  describe "POST /measurements/import" do
    let(:rows) do
      [{ key: "glucose", value: 92.0, unit: "mg/dL", measured_on: Date.current, category: "exam", ref_low: 70, ref_high: 99, source: "pdf" }]
    end
    let(:upload) { Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "exam.pdf") }

    it "creates measurements from the extracted rows" do
      allow(ExamPdfExtractor).to receive(:configured?).and_return(true)
      allow(ExamPdfExtractor).to receive(:new).and_return(instance_double(ExamPdfExtractor, call: ExamPdfExtractor::Result.new(rows: rows, measured_on: Date.current)))

      expect { post import_measurements_path, params: { file: upload } }.to change(account.measurements, :count).by(1)
      expect(response).to redirect_to(measurements_path(category: "exam"))
      expect(account.measurements.find_by(key: "glucose").source).to eq("pdf")
    end

    it "alerts and imports nothing when extraction is not configured" do
      allow(ExamPdfExtractor).to receive(:configured?).and_return(false)
      post import_measurements_path, params: { file: upload }
      expect(response).to redirect_to(measurements_path(category: "exam"))
      expect(account.measurements.count).to eq(0)
    end
  end

  describe "DELETE /measurements/:id" do
    it "removes the measurement" do
      m = create(:measurement, account: account)
      expect { delete measurement_path(m) }.to change(account.measurements, :count).by(-1)
    end

    it "does not delete another account's measurement" do
      other = create(:measurement)
      delete measurement_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end
