# Coordenadas criptografadas (texto no banco, Float no Ruby) e distância em metros.
module GeoPoint
  extend ActiveSupport::Concern

  EARTH_RADIUS_M = 6_371_000.0

  included do
    encrypts :latitude, :longitude, :address
  end

  def lat = latitude.to_f
  def lng = longitude.to_f

  def distance_to(other_lat, other_lng)
    GeoPoint.distance_m(lat, lng, other_lat, other_lng)
  end

  # Haversine.
  def self.distance_m(lat1, lng1, lat2, lng2)
    rad = Math::PI / 180
    dlat = (lat2 - lat1) * rad
    dlng = (lng2 - lng1) * rad
    a = (Math.sin(dlat / 2)**2) + (Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * (Math.sin(dlng / 2)**2))
    2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a))
  end

  def self.valid?(lat, lng)
    lat.is_a?(Numeric) && lng.is_a?(Numeric) && lat.between?(-90, 90) && lng.between?(-180, 180) && !(lat.zero? && lng.zero?)
  end
end
