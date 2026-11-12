# == Schema Information
#
# Table name: workouts
#
#  id               :bigint           not null, primary key
#  activity         :string           not null
#  avg_hr           :decimal(5, 1)
#  date             :date             not null
#  distance_m       :decimal(10, 1)
#  duration_seconds :integer          default(0), not null
#  ended_at         :datetime
#  energy_kcal      :decimal(8, 1)
#  max_hr           :decimal(5, 1)
#  source           :string
#  started_at       :datetime         not null
#  uuid             :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  idx_workouts_unique                    (account_id,uuid) UNIQUE
#  index_workouts_on_account_id           (account_id)
#  index_workouts_on_account_id_and_date  (account_id,date)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Workout < ApplicationRecord
  belongs_to :account

  validates :uuid, presence: true, uniqueness: { scope: :account_id }
  validates :activity, :started_at, :date, presence: true
  validates :duration_seconds, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(started_at: :desc) }

  # Nome de exibição do tipo de treino (i18n -> humanize).
  def activity_label
    I18n.t("workouts.activities.#{activity}", default: activity.to_s.humanize)
  end

  def duration_label
    minutes = duration_seconds / 60
    minutes >= 60 ? "#{minutes / 60}h #{minutes % 60}min" : "#{minutes}min"
  end

  def distance_km
    distance_m.present? && distance_m.positive? ? (distance_m / 1000).round(2) : nil
  end

  # Ritmo em min/km para treinos com distância (corrida, caminhada).
  def pace_label
    km = distance_km
    return nil if km.nil? || km < 0.1 || duration_seconds.zero?

    seconds = (duration_seconds / km).round
    format("%d:%02d /km", seconds / 60, seconds % 60)
  end
end
