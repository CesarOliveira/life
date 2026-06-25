class WeightsController < ApplicationController
  before_action :set_entry, only: [:destroy]

  def index
    load_collection
    @entry = current_account.weight_entries.new(date: Date.current)
  end

  def create
    date = weight_params[:date].presence || Date.current
    @entry = current_account.weight_entries.find_or_initialize_by(date: date)
    @entry.weight_kg = weight_params[:weight_kg]

    if @entry.save
      redirect_to weights_path, notice: t("flash.weights.saved")
    else
      load_collection
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to weights_path, notice: t("flash.weights.removed")
  end

  private

  def load_collection
    @entries = current_account.weight_entries.recent_first.to_a
    @latest = @entries.first
    @chart = WeightChart.new(current_account.weight_entries.chronological.to_a)
  end

  def set_entry
    @entry = current_account.weight_entries.find(params[:id])
  end

  def weight_params
    params.require(:weight_entry).permit(:date, :weight_kg)
  end
end
