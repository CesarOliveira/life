# Monta os dados para um gráfico de linha (SVG) da evolução do peso.
class WeightChart
  Point = Struct.new(:x, :y, :date, :weight, keyword_init: true)

  def initialize(entries, width: 640, height: 200, pad: 28)
    @entries = entries.sort_by(&:date)
    @w = width
    @h = height
    @pad = pad
  end

  attr_reader :w, :h, :pad

  def any?
    @entries.any?
  end

  def points
    return [] if @entries.empty?

    weights = @entries.map { |e| e.weight_kg.to_f }
    wmin = weights.min
    wspan = (weights.max - wmin)
    wspan = 1.0 if wspan.zero?

    dmin = @entries.first.date
    drange = (@entries.last.date - dmin).to_i
    drange = 1 if drange.zero?

    inner_w = @w - (2 * @pad)
    inner_h = @h - (2 * @pad)

    @entries.map do |e|
      dx = @entries.one? ? 0.5 : (e.date - dmin).to_i.to_f / drange
      x = @pad + (dx * inner_w)
      y = @pad + ((1 - ((e.weight_kg.to_f - wmin) / wspan)) * inner_h)
      Point.new(x: x.round(1), y: y.round(1), date: e.date, weight: e.weight_kg)
    end
  end

  def polyline
    points.map { |p| "#{p.x},#{p.y}" }.join(" ")
  end

  def min_weight
    @entries.map(&:weight_kg).min
  end

  def max_weight
    @entries.map(&:weight_kg).max
  end
end
