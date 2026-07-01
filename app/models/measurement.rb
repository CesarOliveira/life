class Measurement < ApplicationRecord
  belongs_to :account

  CATEGORIES = %w[health exam].freeze

  # Catálogo de métricas conhecidas: categoria, unidade e faixa de referência
  # padrão (exames). Chaves fora do catálogo também são aceitas (ex.: extração
  # de PDF) e exibidas com o nome humanizado.
  CATALOG = {
    "sleep_minutes"     => { category: "health", unit: "min" },
    "sleep_bedtime"     => { category: "health", unit: "hh:mm" },
    "sleep_wake"        => { category: "health", unit: "hh:mm" },
    "steps"             => { category: "health", unit: "passos" },
    "resting_hr"        => { category: "health", unit: "bpm" },
    "active_energy"     => { category: "health", unit: "kcal" },
    "glucose"           => { category: "exam", unit: "mg/dL", ref_low: 70, ref_high: 99 },
    "cholesterol_total" => { category: "exam", unit: "mg/dL", ref_high: 190 },
    "hdl"               => { category: "exam", unit: "mg/dL", ref_low: 40 },
    "ldl"               => { category: "exam", unit: "mg/dL", ref_high: 130 },
    "triglycerides"     => { category: "exam", unit: "mg/dL", ref_high: 150 },
    "tsh"               => { category: "exam", unit: "µUI/mL", ref_low: 0.4, ref_high: 4.0 },
    "vitamin_d"         => { category: "exam", unit: "ng/mL", ref_low: 30, ref_high: 100 }
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
    return CATALOG[key.to_s] if CATALOG.key?(key.to_s)

    exam = ExamCatalog.meta(key)
    return {} unless exam

    { category: "exam", unit: exam[:unit], ref_low: exam[:ref_low], ref_high: exam[:ref_high],
      label: exam[:label], panel: exam[:panel] }
  end

  # Chaves do catálogo de uma categoria (para o seletor manual).
  def self.catalog_keys(category)
    keys = CATALOG.select { |_, meta| meta[:category] == category }.keys
    keys += ExamCatalog.keys if category == "exam"
    keys.uniq
  end

  # Nome de exibição de uma chave (catálogo de exames -> i18n -> humanize).
  def self.key_label(key)
    ExamCatalog.meta(key)&.dig(:label) || I18n.t("measurements.keys.#{key}", default: key.to_s.humanize)
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
