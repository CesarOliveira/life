# Saúde: sinais (sono, passos…) e exames (glicemia, colesterol…). Listagem com
# tendência por métrica + entrada manual. Exames podem ter faixa de referência.
class MeasurementsController < ApplicationController
  before_action :set_measurement, only: [:destroy]

  def index
    @category = current_category
    @measurement = current_account.measurements.new(measured_on: Date.current, category: @category)
    @groups = build_groups(@category)
    @catalog_keys = Measurement.catalog_keys(@category)
    @pdf_import = ExamPdfExtractor.configured?
    @panels = ExamCatalog.group(@groups) if @category == "exam"
    load_weight if @category == "health"
  end

  # Importa um PDF de exame: extrai os resultados (IA) e cria as medições.
  def import
    return redirect_with_pdf_alert("not_configured") unless ExamPdfExtractor.configured?

    file = params[:file]
    return redirect_with_pdf_alert("no_file") unless file.respond_to?(:read)

    result = ExamPdfExtractor.new(file.read, today: Date.current).call
    record_extraction(result)
    return redirect_with_pdf_alert(result.error) unless result.ok?

    rows = result.rows.map { |row| row.merge(account_id: current_account.id) }
    rows = rows.reverse.uniq { |row| [row[:key], row[:measured_on]] }.reverse
    if rows.any?
      Measurement.upsert_all(rows, unique_by: :idx_measurements_unique, record_timestamps: true)
      HabitRuleEvaluator.new(current_account).evaluate(rows.map { |row| row[:measured_on] })
    end

    redirect_to measurements_path(category: "exam"), notice: t("measurements.pdf.imported", count: rows.size)
  end

  def create
    date = measurement_params[:measured_on].presence || Date.current
    @measurement = current_account.measurements.find_or_initialize_by(key: measurement_params[:key].to_s, measured_on: date)
    @measurement.assign_attributes(measurement_params.except(:key, :measured_on))
    apply_catalog_defaults(@measurement)

    if @measurement.save
      HabitRuleEvaluator.new(current_account).evaluate([@measurement.measured_on])
      redirect_to measurements_path(category: @measurement.category), notice: t("flash.measurements.saved")
    else
      @category = Measurement::CATEGORIES.include?(@measurement.category) ? @measurement.category : "health"
      @groups = build_groups(@category)
      @catalog_keys = Measurement.catalog_keys(@category)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    category = @measurement.category
    @measurement.destroy
    redirect_to measurements_path(category: category), notice: t("flash.measurements.removed")
  end

  # Apaga todos os exames (para reimportar limpo após ajustes de catálogo).
  def destroy_exams
    current_account.measurements.where(category: "exam").delete_all
    redirect_to measurements_path(category: "exam"), notice: t("measurements.exams_cleared")
  end

  private

  def current_category
    Measurement::CATEGORIES.include?(params[:category]) ? params[:category] : "health"
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

  # Peso agora vive dentro da Saúde (não tem aba própria).
  def load_weight
    @weight_entries = current_account.weight_entries.recent_first.to_a
    @weight_latest = @weight_entries.first
    @weight_chart = WeightChart.new(current_account.weight_entries.chronological.to_a)
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
        rows: group.reverse,
        chart: MetricChart.new(group.map { |m| { date: m.measured_on, value: m.value } })
      }
    end.sort_by { |g| g[:label] }
  end

  # Preenche categoria/unidade a partir do catálogo quando não informados.
  # Faixas de referência NÃO são preenchidas pelo app: vêm do laudo (import)
  # ou do que o usuário digitar — o Life não fornece referência médica.
  def apply_catalog_defaults(measurement)
    meta = Measurement.meta(measurement.key)
    measurement.category = meta[:category] if measurement.category.blank? && meta[:category]
    measurement.category = "health" if measurement.category.blank?
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
    params.require(:measurement).permit(:key, :value, :unit, :measured_on, :category, :ref_low, :ref_high)
  end
end
