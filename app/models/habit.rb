class Habit < ApplicationRecord
  WEEKDAYS = (0..6).to_a.freeze                            # 0=domingo ... 6=sábado
  WEEKDAY_NAMES = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  DEFAULT_COLOR = "#6366f1".freeze

  belongs_to :account
  has_many :habit_checks, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true
  validate :weekdays_within_range

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }

  # Hábito diário = agendado em todos os dias da semana.
  def daily?
    Array(weekdays).map(&:to_i).sort == WEEKDAYS
  end

  # O hábito está agendado para esta data (pelo dia da semana)?
  def scheduled_on?(date)
    Array(weekdays).include?(date.wday)
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
