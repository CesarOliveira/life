# Entrada manual e remoção de resultados de exame (a listagem vive na aba
# Exames de Saúde — MeasurementsController#index).
class ExamResultsController < ApplicationController
  def create
    date = exam_result_params[:measured_on].presence || Date.current
    result = current_account.exam_results.find_or_initialize_by(
      exam_type_id: exam_result_params[:exam_type_id], measured_on: date
    )
    result.assign_attributes(exam_result_params.except(:exam_type_id, :measured_on).merge(source: "manual"))

    if result.save
      redirect_to measurements_path(category: "exam"), notice: t("flash.measurements.saved")
    else
      redirect_to measurements_path(category: "exam"), alert: result.errors.full_messages.to_sentence
    end
  end

  def destroy
    result = current_account.exam_results.find(params[:id])
    result.destroy
    redirect_to measurements_path(category: "exam"), notice: t("flash.measurements.removed")
  end

  private

  def exam_result_params
    params.require(:exam_result).permit(:exam_type_id, :value, :unit, :measured_on, :ref_low, :ref_high)
  end
end
