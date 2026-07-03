# == Schema Information
#
# Table name: habits
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  app_bundle_ids    :string           default([]), not null, is an Array
#  auto              :boolean          default(FALSE), not null
#  color             :string           default("#6366f1"), not null
#  comparator        :string
#  description       :text
#  frequency         :string           default("weekly_days"), not null
#  metric_key        :string
#  name              :string           not null
#  position          :integer          default(0), not null
#  threshold_value   :decimal(12, 3)
#  weekdays          :integer          default([0, 1, 2, 3, 4, 5, 6]), not null, is an Array
#  weekly_target     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  habit_category_id :bigint
#
# Indexes
#
#  index_habits_on_account_id             (account_id)
#  index_habits_on_account_id_and_active  (account_id,active)
#  index_habits_on_habit_category_id      (habit_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (habit_category_id => habit_categories.id)
#
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
  # - `apps: true`     -> soma só os apps escolhidos (app_bundle_ids).
  # - `time_of_day: true` -> o valor/limiar é um horário (minutos desde meia-noite),
  #   comparado com ciclo de meia-noite (ver HabitRuleEvaluator).
  AUTO_METRICS = {
    "screen_time_total" => { source: :app_usage, unit: "h" },
    "social_apps"       => { source: :app_usage, unit: "h", apps: true },
    "sleep_hours"       => { source: :measurement, measurement_key: "sleep_minutes", unit: "h", scale: (1.0 / 60) },
    "sleep_bedtime"     => { source: :measurement, measurement_key: "sleep_bedtime", unit: "hh:mm", time_of_day: true },
    "steps"             => { source: :measurement, measurement_key: "steps", unit: "passos" },
    "resting_hr"        => { source: :measurement, measurement_key: "resting_hr", unit: "bpm" }
  }.freeze

  belongs_to :account
  belongs_to :habit_category, optional: true
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
  validate :apps_selected_for_app_metric, if: :auto?

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

  # A métrica soma apenas apps escolhidos?
  def app_filtered?
    auto? && auto_metric[:apps] == true
  end

  # O limiar é um horário (minutos desde a meia-noite)?
  def time_of_day_metric?
    auto? && auto_metric[:time_of_day] == true
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

  def apps_selected_for_app_metric
    return unless auto_metric[:apps]

    errors.add(:app_bundle_ids, :blank) if Array(app_bundle_ids).reject(&:blank?).empty?
  end
end
