require "rails_helper"

RSpec.describe "API::Exams", type: :request do
  let(:account) { create(:account, api_token: "tok_exams_123") }
  let(:headers) { { "Authorization" => "Bearer tok_exams_123" } }

  it "rejects without a valid token" do
    get "/api/exams"
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the exam results with catalog labels/groups" do
    group = create(:exam_group, key: "funcao_hepatica", name_pt: "Função hepática", name_en: "Liver function")
    type = create(:exam_type, exam_group: group, key: "ast", name_pt: "TGO / AST", name_en: "AST (SGOT)")
    create(:exam_result, account: account, exam_type: type, value: 23, unit: "U/L",
                         ref_low: 10, ref_high: 38, measured_on: Date.new(2026, 2, 10), source: "pdf")

    get "/api/exams", headers: headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["count"]).to eq(1)
    exam = body["exams"].first
    expect(exam["key"]).to eq("ast")
    expect(exam["label"]).to eq("TGO / AST")
    expect(exam["panel"]).to eq("funcao_hepatica")
    expect(exam["value"]).to eq(23.0)
    expect(exam["ref_low"]).to eq(10.0)
    expect(exam["measured_on"]).to eq("2026-02-10")
  end
end
