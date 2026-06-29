class Habit < ApplicationRecord
  WEEKDAYS = (0..6).to_a.freeze                            # 0=domingo ... 6=sábado
  WEEKDAY_NAMES = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  DEFAULT_COLOR = "#6366f1".freeze

  # Cadência do hábito:
  # - weekly_days:  dias específicos da semana (usa `weekdays`).
  # - weekly_count: Nx por semana em qualquer dia (usa `weekly_target`).
  FREQUENCIES = %w[weekly_days weekly_count].freeze

  COMPARATORS = %w[lte gte].freeze

  # Métricas que alimentam hábitos automáticos. `source` define de onde sai o
  # valor do dia; `unit` é a unidade do limiar exibida ao usuário.
  AUTO_METRICS = {
    "screen_time_total" => { source: :app_usage, unit: "h" },
    "sleep_hours"       => { source: :measurement, measurement_key: "sleep_minutes", unit: "h", scale: (1.0 / 60) },
    "steps"             => { source: :measurement, measurement_key: "steps", unit: "passos" },
    "resting_hr"        => { source: :measurement, measurement_key: "resting_hr", unit: "bpm" }
  }.freeze

  belongs_to :account
  has_many :habit_checks, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :weekly_target,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 7 },
            if: :weekly_count?
  validate :weekdays_within_range, unless: -> { weekly_count? || auto? }

  validates :metric_key, inclusion: { in: AUTO_METRICS.keys }, if: :auto?
  validates :comparator, inclusion: { in: COMPARATORS }, if: :auto?
  validates :threshold_value, presence: true, numericality: true, if: :auto?

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }
  scope :automatic, -> { where(auto: true) }

  def weekly_count?
    frequency == "weekly_count"
  end

  def weekly_days?
    frequency == "weekly_days"
  end

  def auto_metric
    AUTO_METRICS[metric_key] || {}
  end

  # Hábito diário = agendado em todos os dias da semana.
  def daily?
    weekly_days? && Array(weekdays).map(&:to_i).sort == WEEKDAYS
  end

  # O hábito está agendado para esta data?
  # weekly_count e auto são avaliados todos os dias.
  def scheduled_on?(date)
    return true if weekly_count? || auto?

    Array(weekdays).include?(date.wday)
  end

  # Marcações esperadas por semana (base da meta semanal e da força).
  def effective_weekly_target
    weekly_count? ? weekly_target.to_i : Array(weekdays).map(&:to_i).uniq.size
  end

  # Foi marcado como feito nesta data? Usa a associação já carregada quando possível.
  def checked_on?(date)
    if habit_checks.loaded?
      habit_checks.any? { |c| c.date == date }
    else
      habit_checks.exists?(date: date)
    end
  end

  private

  def weekdays_within_range
    days = Array(weekdays)
    if days.empty?
      errors.add(:weekdays, "selecione ao menos um dia da semana")
    elsif days.any? { |d| !WEEKDAYS.include?(d.to_i) }
      errors.add(:weekdays, "contém um dia inválido")
    end
  end
end
