module Api
  # GET /api/exams — leitura dos exames (ExamResult) via token pessoal.
  # Útil para exportar/conferir os dados importados (ex.: comparar com o PDF).
  class ExamsController < BaseController
    def index
      rows = current_account.exam_results.includes(exam_type: :exam_group).order(:measured_on).to_a
      render json: {
        ok: true,
        count: rows.size,
        exams: rows.map do |r|
          {
            key: r.exam_type.key,
            label: r.exam_type.name,
            panel: r.exam_type.exam_group.key,
            value: r.value.to_f,
            unit: r.unit,
            measured_on: r.measured_on.iso8601,
            ref_low: r.ref_low&.to_f,
            ref_high: r.ref_high&.to_f,
            source: r.source
          }
        end
      }
    end
  end
end
