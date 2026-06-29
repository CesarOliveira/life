# Gráfico de linha (SVG) genérico a partir de uma série de pontos
# { date:, value: }. Usado para a tendência de medições de saúde/exames.
class MetricChart
  Point = Struct.new(:x, :y, :date, :value, keyword_init: true)

  def initialize(series, width: 640, height: 200, pad: 28)
    @series = series.sort_by { |p| p[:date] }
    @w = width
    @h = height
    @pad = pad
  end

  attr_reader :w, :h, :pad

  def any?
    @series.any?
  end

  def min
    @series.map { |p| p[:value].to_f }.min
  end

  def max
    @series.map { |p| p[:value].to_f }.max
  end

  def points
    return [] if @series.empty?

    vmin = min
    vspan = max - vmin
    vspan = 1.0 if vspan.zero?

    dmin = @series.first[:date]
    drange = (@series.last[:date] - dmin).to_i
    drange = 1 if drange.zero?

    inner_w = @w - (2 * @pad)
    inner_h = @h - (2 * @pad)

    @series.map do |p|
      dx = @series.one? ? 0.5 : (p[:date] - dmin).to_i.to_f / drange
      x = @pad + (dx * inner_w)
      y = @pad + ((1 - ((p[:value].to_f - vmin) / vspan)) * inner_h)
      Point.new(x: x.round(1), y: y.round(1), date: p[:date], value: p[:value])
    end
  end

  def polyline
    points.map { |p| "#{p.x},#{p.y}" }.join(" ")
  end
end
