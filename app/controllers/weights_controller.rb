# Peso vive dentro da Saúde (measurements, categoria health) — sem aba própria.
# Aqui só criamos/removemos entradas e voltamos para a Saúde.
class WeightsController < ApplicationController
  before_action :set_entry, only: [:destroy]

  def create
    date = weight_params[:date].presence || Date.current
    @entry = current_account.weight_entries.find_or_initialize_by(date: date)
    @entry.weight_kg = weight_params[:weight_kg]

    if @entry.save
      redirect_to measurements_path(category: "health"), notice: t("flash.weights.saved")
    else
      redirect_to measurements_path(category: "health"), alert: @entry.errors.full_messages.to_sentence
    end
  end

  def destroy
    @entry.destroy
    redirect_to measurements_path(category: "health"), notice: t("flash.weights.removed")
  end

  private

  def set_entry
    @entry = current_account.weight_entries.find(params[:id])
  end

  def weight_params
    params.require(:weight_entry).permit(:date, :weight_kg)
  end
end
