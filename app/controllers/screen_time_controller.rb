class ScreenTimeController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token

    @today = Date.current
    @range = (@today - 6.days)..@today
    usages = current_account.app_usages.in_range(@range)

    @total_week = usages.sum(:seconds)
    @total_today = usages.where(date: @today).sum(:seconds)

    names = usages.where.not(name: nil).group(:bundle_id).maximum(:name)
    @apps = usages.group(:bundle_id).sum(:seconds)
                  .map { |bundle_id, seconds| { bundle_id: bundle_id, name: names[bundle_id].presence || bundle_id, seconds: seconds } }
                  .sort_by { |a| -a[:seconds] }
    @max_app = @apps.map { |a| a[:seconds] }.max || 0
  end

  # Token inteiro (texto puro) — buscado pela ação "Copiar" só na hora de copiar,
  # para não exibir o token completo na página.
  def token
    render plain: current_account.api_token.to_s
  end

  # Histórico diário de um app específico (gráfico).
  def app
    @bundle_id = params[:bundle_id].to_s
    return redirect_to(screen_time_path) if @bundle_id.blank?

    @today = Date.current
    @range = (@today - 29.days)..@today
    rows = current_account.app_usages.where(bundle_id: @bundle_id, date: @range)
    @name = rows.where.not(name: nil).maximum(:name).presence || @bundle_id

    by_date = rows.group(:date).sum(:seconds)
    @total = by_date.values.sum
    @days = by_date.size
    # Barras horizontais, um dia por linha (mais legível no celular que linha).
    @daily = by_date.sort_by { |date, _| date }.reverse.map { |date, seconds| { date: date, seconds: seconds } }
    @max_day = by_date.values.max || 0
  end

  def regenerate
    current_account.regenerate_api_token
    redirect_back fallback_location: setup_path, notice: t("flash.screen_time.token_regenerated")
  end
end
