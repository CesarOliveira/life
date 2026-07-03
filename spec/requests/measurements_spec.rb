require "rails_helper"

RSpec.describe "Measurements", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  def liver_type
    group = ExamGroup.find_by(key: "funcao_hepatica") ||
            create(:exam_group, key: "funcao_hepatica", name_pt: "Função hepática", name_en: "Liver function")
    ExamType.find_by(key: "ast") ||
      create(:exam_type, exam_group: group, key: "ast", name_pt: "TGO / AST", name_en: "AST (SGOT)")
  end

  describe "GET /measurements" do
    it "shows health signals by default" do
      create(:measurement, account: account, key: "steps", value: 9000)
      get measurements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("measurements.keys.steps"))
    end

    it "shows exam results grouped by catalog group when filtered" do
      create(:exam_result, account: account, exam_type: liver_type, value: 23, unit: "U/L")
      get measurements_path(category: "exam")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Função hepática")
      expect(response.body).to include("TGO / AST")
    end
  end

  describe "POST /measurements (sinais)" do
    it "creates a health measurement with unit from the catalog" do
      expect {
        post measurements_path, params: { measurement: { key: "steps", value: "9000", measured_on: Date.current.iso8601 } }
      }.to change(account.measurements, :count).by(1)

      m = account.measurements.last
      expect(m.category).to eq("health")
      expect(m.unit).to eq("passos")
    end

    it "overwrites the same key/date instead of duplicating" do
      post measurements_path, params: { measurement: { key: "steps", value: "5000", measured_on: Date.current.iso8601 } }
      expect {
        post measurements_path, params: { measurement: { key: "steps", value: "8000", measured_on: Date.current.iso8601 } }
      }.not_to change(account.measurements, :count)
      expect(account.measurements.find_by(key: "steps").value).to eq(8000)
    end
  end

  describe "POST /exam_results (entrada manual de exame)" do
    it "creates a result with the user-typed reference range" do
      type = liver_type
      expect {
        post exam_results_path, params: { exam_result: { exam_type_id: type.id, value: "23", unit: "U/L",
                                                         measured_on: Date.current.iso8601, ref_low: "10", ref_high: "38" } }
      }.to change(account.exam_results, :count).by(1)

      r = account.exam_results.last
      expect(r.source).to eq("manual")
      expect(r.ref_high).to eq(38)
    end

    it "upserts the same type/date" do
      type = liver_type
      create(:exam_result, account: account, exam_type: type, value: 20, measured_on: Date.current)
      expect {
        post exam_results_path, params: { exam_result: { exam_type_id: type.id, value: "25", measured_on: Date.current.iso8601 } }
      }.not_to change(account.exam_results, :count)
      expect(account.exam_results.find_by(exam_type: type, measured_on: Date.current).value).to eq(25)
    end
  end

  describe "POST /measurements/import" do
    let(:rows) do
      [{ key: "ast", value: 23.0, unit: "U/L", measured_on: Date.current, ref_low: 10, ref_high: 38, source: "pdf" },
       { key: "desconhecido", value: 1.0, unit: nil, measured_on: Date.current, ref_low: nil, ref_high: nil, source: "pdf" }]
    end
    let(:upload) { Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "exam.pdf") }

    it "creates exam results from the extracted rows (ignoring unknown keys)" do
      liver_type
      allow(ExamPdfExtractor).to receive(:configured?).and_return(true)
      allow(ExamPdfExtractor).to receive(:new).and_return(instance_double(ExamPdfExtractor, call: ExamPdfExtractor::Result.new(rows: rows, measured_on: Date.current)))

      expect { post import_measurements_path, params: { file: upload } }.to change(account.exam_results, :count).by(1)
      expect(response).to redirect_to(measurements_path(category: "exam"))
      result = account.exam_results.last
      expect(result.exam_type.key).to eq("ast")
      expect(result.source).to eq("pdf")
      expect(result.ref_high).to eq(38)
    end

    it "alerts and imports nothing when extraction is not configured" do
      allow(ExamPdfExtractor).to receive(:configured?).and_return(false)
      post import_measurements_path, params: { file: upload }
      expect(response).to redirect_to(measurements_path(category: "exam"))
      expect(account.exam_results.count).to eq(0)
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

  describe "favoritar grupo" do
    it "toggles the favorite and pins the group first" do
      liver = liver_type
      other_group = create(:exam_group, key: "aaa_grupo", name_pt: "AAA Grupo", name_en: "AAA Group", position: 0)
      other_type = create(:exam_type, exam_group: other_group, key: "outro", name_pt: "Outro", name_en: "Other")
      create(:exam_result, account: account, exam_type: liver, value: 23)
      create(:exam_result, account: account, exam_type: other_type, value: 1)

      post toggle_exam_group_favorite_path(liver.exam_group)
      expect(liver.exam_group.reload.favorite).to be(true)

      get measurements_path(category: "exam")
      body = response.body
      expect(body.index("Função hepática")).to be < body.index("AAA Grupo") # favorito vem antes
    end
  end

  describe "DELETE /measurements/destroy_exams" do
    it "clears all exam results (keeps health measurements)" do
      create(:exam_result, account: account, exam_type: liver_type)
      create(:measurement, account: account, category: "health", key: "steps")
      delete destroy_exams_measurements_path
      expect(account.exam_results.count).to eq(0)
      expect(account.measurements.count).to eq(1)
    end
  end
end
