class ScreenTimeController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token

    @today = Date.current
    @range = (@today - 6.days)..@today
    usages = current_account.app_usages.in_range(@range)

    @total_week = usages.sum(:seconds)
    # "Hoje" é sempre 0 (o atalho envia o dia anterior); mostramos "Ontem".
    @total_yesterday = current_account.app_usages.where(date: @today - 1).sum(:seconds)

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

  # Histórico do tempo de tela TOTAL por dia, com filtro de período e gráfico
  # (barras ou linha — a troca é no cliente).
  RANGES = { "7" => 7, "30" => 30, "90" => 90, "365" => 365 }.freeze

  def history
    @today = Date.current
    @from, @to, @range_key = resolve_range
    usages = current_account.app_usages.where(date: @from..@to)

    @total = usages.sum(:seconds)
    by_date = usages.group(:date).sum(:seconds)
    # Só dias COM registro: o gráfico não cai a zero em dias sem dado e termina
    # no último registro real.
    @daily = by_date.sort_by { |date, _| date }.map { |date, seconds| { date: date, seconds: seconds } }
    @max_day = by_date.values.max || 0
    days_in_period = (@to - @from).to_i + 1
    @avg = days_in_period.positive? ? (@total / days_in_period) : 0
    @chart = MetricChart.new(@daily.map { |d| { date: d[:date], value: (d[:seconds] / 3600.0).round(2) } })
  end

  def regenerate
    current_account.regenerate_api_token
    redirect_back fallback_location: setup_path, notice: t("flash.screen_time.token_regenerated")
  end

  private

  # Resolve o intervalo: from/to específicos, ou range predefinido (dias).
  def resolve_range
    today = Date.current
    from = parse_date(params[:from])
    to = parse_date(params[:to])
    return [from, [to, today].min, "custom"] if from && to && from <= to

    key = RANGES.key?(params[:range]) ? params[:range] : "30"
    [today - (RANGES[key] - 1), today, key]
  end

  def parse_date(raw)
    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
