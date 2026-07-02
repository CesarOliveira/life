# == Schema Information
#
# Table name: measurements
#
#  id          :bigint           not null, primary key
#  category    :string           default("health"), not null
#  key         :string           not null
#  measured_on :date             not null
#  ref_high    :decimal(12, 3)
#  ref_low     :decimal(12, 3)
#  source      :string           default("manual"), not null
#  unit        :string
#  value       :decimal(12, 3)   not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  idx_measurements_unique                        (account_id,key,measured_on) UNIQUE
#  index_measurements_on_account_id               (account_id)
#  index_measurements_on_account_id_and_category  (account_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Measurement < ApplicationRecord
  belongs_to :account

  CATEGORIES = %w[health exam].freeze

  # Catálogo de métricas de SAÚDE (sinais). Exames vivem em ExamType/ExamResult.
  CATALOG = {
    "sleep_minutes" => { category: "health", unit: "min" },
    "sleep_bedtime" => { category: "health", unit: "hh:mm" },
    "sleep_wake"    => { category: "health", unit: "hh:mm" },
    "steps"         => { category: "health", unit: "passos" },
    "resting_hr"    => { category: "health", unit: "bpm" },
    "active_energy" => { category: "health", unit: "kcal" }
  }.freeze

  validates :key, presence: true
  validates :value, presence: true, numericality: true
  validates :measured_on, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :key, uniqueness: { scope: [:account_id, :measured_on] }

  scope :health, -> { where(category: "health") }
  scope :exams, -> { where(category: "exam") }
  scope :for_key, ->(value) { where(key: value) }
  scope :chronological, -> { order(:measured_on) }
  scope :recent_first, -> { order(measured_on: :desc) }

  def self.meta(key)
    CATALOG[key.to_s] || {}
  end

  # Chaves do catálogo de uma categoria (para o seletor manual).
  def self.catalog_keys(category)
    CATALOG.select { |_, meta| meta[:category] == category }.keys
  end

  # Nome de exibição de uma chave (i18n -> humanize).
  def self.key_label(key)
    I18n.t("measurements.keys.#{key}", default: key.to_s.humanize)
  end

  def out_of_range?
    return false if value.nil?

    (ref_low.present? && value < ref_low) || (ref_high.present? && value > ref_high)
  end

  def label
    self.class.key_label(key)
  end

  # Chaves cujo valor é um horário (minutos desde a meia-noite) -> exibir HH:MM.
  TIME_KEYS = %w[sleep_bedtime sleep_wake].freeze
  # Chaves cujo valor é uma duração em minutos -> exibir "Xh Ym".
  DURATION_KEYS = %w[sleep_minutes].freeze

  def time_of_day?
    TIME_KEYS.include?(key.to_s)
  end

  def duration?
    DURATION_KEYS.include?(key.to_s)
  end

  # Mostra valor sem a unidade separada (horário ou duração já são auto-explicativos).
  def self_explanatory?
    time_of_day? || duration?
  end

  # Valor formatado para exibição: horários HH:MM; durações "Xh Ym"; demais número.
  def display_value
    return value if value.nil?
    return format("%02d:%02d", value.to_i / 60, value.to_i % 60) if time_of_day?
    return duration_label if duration?

    value == value.to_i ? value.to_i : value
  end

  def duration_label
    minutes = value.to_i
    hours = minutes / 60
    rest = minutes % 60
    hours.positive? ? "#{hours}h #{rest}min" : "#{rest}min"
  end
end
