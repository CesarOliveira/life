# Uma permanência num ponto: chegada e saída (saída vazia = ainda está lá).
# Fontes: "iphone" (CLVisit do app nativo) e "google" (importação da Linha do Tempo).
# == Schema Information
#
# Table name: visits
#
#  id          :bigint           not null, primary key
#  accuracy_m  :integer
#  address     :text
#  arrived_at  :datetime         not null
#  date        :date             not null
#  departed_at :datetime
#  hint        :string
#  latitude    :text             not null
#  longitude   :text             not null
#  source      :string           default("iphone"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  external_id :string           not null
#  place_id    :bigint
#
# Indexes
#
#  index_visits_on_account_id                  (account_id)
#  index_visits_on_account_id_and_arrived_at   (account_id,arrived_at)
#  index_visits_on_account_id_and_date         (account_id,date)
#  index_visits_on_account_id_and_external_id  (account_id,external_id) UNIQUE
#  index_visits_on_place_id                    (place_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (place_id => places.id) ON DELETE => nullify
#
class Visit < ApplicationRecord
  include GeoPoint

  SOURCES = %w[iphone google].freeze

  belongs_to :account
  belongs_to :place, optional: true

  validates :arrived_at, :date, :latitude, :longitude, :external_id, presence: true
  validates :source, inclusion: { in: SOURCES }
  validate :departure_after_arrival

  scope :chronological, -> { order(:arrived_at) }
  scope :unassigned, -> { where(place_id: nil) }

  # Visitas que tocam o dia local [início, fim).
  scope :overlapping, lambda { |from, to|
    where(arrived_at: ...to).where("departed_at IS NULL OR departed_at > ?", from)
  }

  # Segundos dentro do intervalo (saída vazia conta até `now`).
  def seconds_within(from, to, now: Time.current)
    finish = departed_at || [now, to].min
    [[finish, to].min - [arrived_at, from].max, 0].max
  end

  def duration_seconds(now: Time.current)
    ((departed_at || now) - arrived_at).clamp(0, Float::INFINITY)
  end

  private

  def departure_after_arrival
    errors.add(:departed_at, :invalid) if departed_at && arrived_at && departed_at < arrived_at
  end
end
