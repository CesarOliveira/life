# == Schema Information
#
# Table name: oauth_clients
#
#  id                  :bigint           not null, primary key
#  kind                :string           default("dcr"), not null
#  metadata_fetched_at :datetime
#  name                :string
#  redirect_uris       :string           default([]), not null, is an Array
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  client_id           :string           not null
#
# Indexes
#
#  index_oauth_clients_on_client_id  (client_id) UNIQUE
#
class OauthClient < ApplicationRecord
  KINDS = %w[dcr cimd].freeze
  FORBIDDEN_SCHEMES = %w[javascript data file vbscript blob about].freeze
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1] ::1].freeze

  has_many :grants, class_name: "OauthGrant", dependent: :destroy

  validates :client_id, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validate :redirect_uris_are_safe

  def display_name
    name.presence || URI.parse(redirect_uris.first.to_s).host || client_id
  rescue URI::InvalidURIError
    client_id
  end

  # O redirect pedido bate com um cadastrado? Comparação exata, exceto loopback
  # (http://localhost ou 127.0.0.1), em que a porta é livre (RFC 8252): apps de
  # desktop abrem uma porta diferente a cada login.
  def redirect_uri_allowed?(uri)
    return false if uri.blank?
    return true if redirect_uris.include?(uri)

    requested = self.class.parse_uri(uri)
    return false unless requested && self.class.loopback?(requested)

    redirect_uris.any? do |registered|
      candidate = self.class.parse_uri(registered)
      candidate && self.class.loopback?(candidate) && candidate.host == requested.host && candidate.path == requested.path
    end
  end

  def self.parse_uri(value)
    URI.parse(value.to_s)
  rescue URI::InvalidURIError
    nil
  end

  def self.loopback?(uri)
    uri.scheme == "http" && LOOPBACK_HOSTS.include?(uri.host.to_s)
  end

  # https sempre; http só em loopback; esquemas próprios de apps (cursor://…) ok;
  # nada de javascript:, data: etc., nem fragmento.
  def self.safe_redirect_uri?(value)
    uri = parse_uri(value)
    return false if uri.nil? || uri.scheme.blank? || uri.fragment.present? || value.to_s.length > 500
    return false if FORBIDDEN_SCHEMES.include?(uri.scheme.downcase)
    return uri.host.present? if uri.scheme == "https"
    return loopback?(uri) if uri.scheme == "http"

    uri.scheme.match?(/\A[a-z][a-z0-9+.-]*\z/i)
  end

  private

  def redirect_uris_are_safe
    errors.add(:redirect_uris, :blank) if redirect_uris.blank?
    errors.add(:redirect_uris, :invalid) unless Array(redirect_uris).all? { |uri| self.class.safe_redirect_uri?(uri) }
  end
end
