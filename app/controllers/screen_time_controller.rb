class ScreenTimeController < ApplicationController
  # Períodos rápidos (estilo iOS): hoje, ontem (padrão — o atalho envia o dia
  # anterior), últimos 7/15/30 dias. Além disso: select de 2..12 meses e
  # intervalo livre (data início + fim).
  DAY_RANGES = { "7" => 7, "15" => 15, "30" => 30 }.freeze
  MONTHS_OPTIONS = (2..12).to_a.freeze

  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token

    resolve_period(default_range: "yesterday")

    usages = current_account.app_usages.where(date: @from..@to)
    @total = usages.sum(:seconds)
    by_date = usages.group(:date).sum(:seconds)
    # Todos os dias do período (dias sem dado = barra vazia, como no iPhone).
    @daily = (@from..@to).map { |d| { date: d, seconds: by_date[d] || 0 } }
    @max_day = @daily.map { |d| d[:seconds] }.max || 0
    days_with_data = by_date.size
    @avg = days_with_data.positive? ? (by_date.values.sum / days_with_data) : 0

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

  # Histórico diário de um app específico (gráfico de linha) — mesmo filtro de
  # período do índice.
  def app
    @bundle_id = params[:bundle_id].to_s
    return redirect_to(screen_time_path) if @bundle_id.blank?

    resolve_period(default_range: "30")
    rows = current_account.app_usages.where(bundle_id: @bundle_id, date: @from..@to)
    @name = rows.where.not(name: nil).maximum(:name).presence || @bundle_id

    by_date = rows.group(:date).sum(:seconds)
    @total = by_date.values.sum
    @days = by_date.size
    # Só dias COM registro: o gráfico de linha não cai a zero em dias sem dado.
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
  end

  def regenerate
    current_account.regenerate_api_token
    redirect_back fallback_location: setup_path, notice: t("flash.screen_time.token_regenerated")
  end

  private

  # Define @from/@to/@range_key/@months a partir dos params (intervalo livre,
  # meses, dias rápidos ou o padrão da tela). @today também.
  def resolve_period(default_range:)
    @today = Date.current
    @months = params[:months].to_i

    from = parse_date(params[:from])
    to = parse_date(params[:to])
    if from && to && from <= to
      @from = from
      @to = [to, @today].min
      @range_key = "custom"
    elsif MONTHS_OPTIONS.include?(@months)
      @from = @today - @months.months
      @to = @today
      @range_key = "months"
    elsif params[:range] == "today"
      @from = @to = @today
      @range_key = "today"
    elsif params[:range] == "yesterday"
      @from = @to = @today - 1
      @range_key = "yesterday"
    elsif DAY_RANGES.key?(params[:range])
      @range_key = params[:range]
      @to = @today
      @from = @today - (DAY_RANGES[@range_key] - 1)
    elsif default_range == "yesterday"
      @from = @to = @today - 1
      @range_key = "yesterday"
    else
      @range_key = default_range
      @to = @today
      @from = @today - (DAY_RANGES[default_range] - 1)
    end
  end

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
