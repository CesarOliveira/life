# Saúde: sinais (sono, passos…) em Measurement e exames (glicemia, hemograma…)
# em ExamResult (catálogo em ExamGroup/ExamType). Listagem com tendência +
# entrada manual + import de PDF.
class MeasurementsController < ApplicationController
  before_action :set_measurement, only: [:destroy]

  def index
    @category = current_category
    @pdf_import = ExamPdfExtractor.configured?
    if @category == "exam"
      load_exams
    else
      @measurement = current_account.measurements.new(measured_on: Date.current, category: "health")
      @groups = build_groups("health")
      @catalog_keys = Measurement.catalog_keys("health")
      load_weight
    end
  end

  # Importa um PDF de exame: extrai os resultados (IA) e cria os ExamResult.
  def import
    return redirect_with_pdf_alert("not_configured") unless ExamPdfExtractor.configured?

    file = params[:file]
    return redirect_with_pdf_alert("no_file") unless file.respond_to?(:read)

    result = ExamPdfExtractor.new(file.read, today: Date.current).call
    record_extraction(result)
    return redirect_with_pdf_alert(result.error) unless result.ok?

    count = store_exam_rows(result.rows)
    redirect_to measurements_path(category: "exam"), notice: t("measurements.pdf.imported", count: count)
  end

  def create
    date = measurement_params[:measured_on].presence || Date.current
    @measurement = current_account.measurements.find_or_initialize_by(key: measurement_params[:key].to_s, measured_on: date)
    @measurement.assign_attributes(measurement_params.except(:key, :measured_on))
    apply_catalog_defaults(@measurement)

    if @measurement.save
      HabitRuleEvaluator.new(current_account).evaluate([@measurement.measured_on])
      redirect_to measurements_path(category: "health"), notice: t("flash.measurements.saved")
    else
      @category = "health"
      @groups = build_groups("health")
      @catalog_keys = Measurement.catalog_keys("health")
      load_weight
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @measurement.destroy
    redirect_to measurements_path(category: "health"), notice: t("flash.measurements.removed")
  end

  # Apaga todos os exames (para reimportar limpo após ajustes de catálogo).
  def destroy_exams
    current_account.exam_results.delete_all
    redirect_to measurements_path(category: "exam"), notice: t("measurements.exams_cleared")
  end

  private

  def current_category
    Measurement::TABS.include?(params[:category]) ? params[:category] : "health"
  end

  # Exames agrupados: grupos do catálogo -> tipos com resultados -> série.
  def load_exams
    results = current_account.exam_results.includes(exam_type: :exam_group).chronological.to_a
    by_type = results.group_by(&:exam_type)
    @exam_result = current_account.exam_results.new(measured_on: Date.current)
    # Select agrupado: [ [nome do grupo, [[nome do exame, id], ...]], ... ],
    # grupos e exames em ordem alfabética.
    @exam_type_options = ExamType.includes(:exam_group).group_by(&:exam_group)
                                 .sort_by { |group, _| group.name.downcase }
                                 .map do |group, types|
      [group.name, types.sort_by { |t| t.name.downcase }.map { |t| [t.name, t.id] }]
    end
    @exam_groups = by_type.keys.group_by(&:exam_group)
                          .sort_by { |g, _| [g.favorite ? 0 : 1, g.position, g.id] }.map do |group, types|
      {
        group: group,
        items: types.sort_by { |t| [t.position, t.id] }.map do |type|
          rows = by_type[type]
          {
            type: type,
            latest: rows.last,
            rows: rows.reverse
          }
        end
      }
    end
  end

  # Grava as linhas extraídas do PDF como ExamResult (mapeando key -> ExamType).
  # Chaves fora do catálogo são ignoradas (o prompt já restringe às conhecidas).
  def store_exam_rows(rows)
    types = ExamType.where(key: rows.map { |r| r[:key] }.uniq).index_by(&:key)
    payload = rows.filter_map do |row|
      type = types[row[:key]]
      next if type.nil?

      { account_id: current_account.id, exam_type_id: type.id, value: row[:value], unit: row[:unit],
        measured_on: row[:measured_on], ref_low: row[:ref_low], ref_high: row[:ref_high], source: "pdf" }
    end
    payload = payload.reverse.uniq { |r| [r[:exam_type_id], r[:measured_on]] }.reverse
    ExamResult.upsert_all(payload, unique_by: :idx_exam_results_unique, record_timestamps: true) if payload.any?
    payload.size
  end

  # Registra a extração (tokens/custo) para acompanhamento no /admin.
  def record_extraction(result)
    usage = result.usage || {}
    current_account.exam_extractions.create!(
      file_bytes: usage[:file_bytes].to_i,
      models_used: usage[:models_used].to_s,
      input_tokens: usage[:input_tokens].to_i,
      output_tokens: usage[:output_tokens].to_i,
      cost_usd: usage[:cost_usd] || 0,
      rows_count: result.rows&.size.to_i,
      status: result.ok? ? "success" : "failed",
      error: result.error,
      duration_ms: usage[:duration_ms].to_i
    )
  rescue StandardError => e
    Rails.logger.error("record_extraction: #{e.class}: #{e.message}")
  end

  # Peso vive dentro da Saúde (não tem aba própria).
  def load_weight
    @weight_entries = current_account.weight_entries.recent_first.to_a
    @weight_latest = @weight_entries.first
    @weight_entry = current_account.weight_entries.new(date: Date.current)
  end

  # Agrupa as medições por chave: [{ key, label, unit, latest, rows, chart }, ...].
  def build_groups(category)
    rows = current_account.measurements.where(category: category).chronological.to_a
    rows.group_by(&:key).map do |key, group|
      {
        key: key,
        label: group.first.label,
        unit: group.first.unit,
        latest: group.last,
        rows: group.reverse
      }
    end.sort_by { |g| g[:label] }
  end

  # Preenche categoria/unidade a partir do catálogo quando não informados.
  def apply_catalog_defaults(measurement)
    meta = Measurement.meta(measurement.key)
    measurement.category = "health"
    measurement.unit = meta[:unit] if measurement.unit.blank? && meta[:unit]
  end

  def redirect_with_pdf_alert(error)
    key = "measurements.pdf.errors.#{error}"
    message = I18n.exists?(key) ? t(key) : t("measurements.pdf.errors.extraction_failed")
    redirect_to measurements_path(category: "exam"), alert: message
  end

  def set_measurement
    @measurement = current_account.measurements.find(params[:id])
  end

  def measurement_params
    params.require(:measurement).permit(:key, :value, :unit, :measured_on, :category)
  end
end
