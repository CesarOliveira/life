module Api
  # GET /api/exams — leitura dos exames (categoria "exam") via token pessoal.
  # Útil para exportar/conferir os dados importados (ex.: comparar com o PDF).
  class ExamsController < BaseController
    def index
      rows = current_account.measurements.exams.order(:measured_on, :key)
      render json: {
        ok: true,
        count: rows.size,
        exams: rows.map do |m|
          {
            key: m.key,
            label: m.label,
            panel: ExamCatalog.meta(m.key)&.dig(:panel),
            value: m.value.to_f,
            unit: m.unit,
            measured_on: m.measured_on.iso8601,
            ref_low: m.ref_low&.to_f,
            ref_high: m.ref_high&.to_f,
            source: m.source
          }
        end
      }
    end
  end
end
