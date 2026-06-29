# Saúde: sinais (sono, passos…) e exames (glicemia, colesterol…). Listagem com
# tendência por métrica + entrada manual. Exames podem ter faixa de referência.
class MeasurementsController < ApplicationController
  before_action :set_measurement, only: [:destroy]

  def index
    @category = current_category
    @measurement = current_account.measurements.new(measured_on: Date.current, category: @category)
    @groups = build_groups(@category)
    @catalog_keys = Measurement.catalog_keys(@category)
  end

  def create
    date = measurement_params[:measured_on].presence || Date.current
    @measurement = current_account.measurements.find_or_initialize_by(key: measurement_params[:key].to_s, measured_on: date)
    @measurement.assign_attributes(measurement_params.except(:key, :measured_on))
    apply_catalog_defaults(@measurement)

    if @measurement.save
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

  private

  def current_category
    Measurement::CATEGORIES.include?(params[:category]) ? params[:category] : "health"
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

  # Preenche categoria/unidade/faixa a partir do catálogo quando não informados.
  def apply_catalog_defaults(measurement)
    meta = Measurement.meta(measurement.key)
    measurement.category = meta[:category] if measurement.category.blank? && meta[:category]
    measurement.category = "health" if measurement.category.blank?
    measurement.unit = meta[:unit] if measurement.unit.blank? && meta[:unit]
    return unless measurement.category == "exam"

    measurement.ref_low = meta[:ref_low] if measurement.ref_low.blank? && meta[:ref_low]
    measurement.ref_high = meta[:ref_high] if measurement.ref_high.blank? && meta[:ref_high]
  end

  def set_measurement
    @measurement = current_account.measurements.find(params[:id])
  end

  def measurement_params
    params.require(:measurement).permit(:key, :value, :unit, :measured_on, :category, :ref_low, :ref_high)
  end
end
