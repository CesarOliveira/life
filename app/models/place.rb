# Lugar nomeado pela pessoa ("Casa", "Academia"). Visitas dentro do raio ganham este lugar.
# == Schema Information
#
# Table name: places
#
#  id         :bigint           not null, primary key
#  address    :text
#  latitude   :text             not null
#  longitude  :text             not null
#  name       :string           not null
#  radius_m   :integer          default(120), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_places_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Place < ApplicationRecord
  include GeoPoint

  MIN_RADIUS = 30
  MAX_RADIUS = 2000

  belongs_to :account
  has_many :visits, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 }
  validates :latitude, :longitude, presence: true
  validates :radius_m, numericality: { only_integer: true, greater_than_or_equal_to: MIN_RADIUS, less_than_or_equal_to: MAX_RADIUS }

  scope :ordered, -> { order(:name) }

  # A visita cai neste lugar? Tolera parte da imprecisão do GPS (até 100 m).
  def covers?(visit_lat, visit_lng, accuracy_m = nil)
    distance_to(visit_lat, visit_lng) <= radius_m + [accuracy_m.to_i, 100].min
  end
end
