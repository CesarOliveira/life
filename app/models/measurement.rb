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

  CATEGORIES = %w[health exam productivity].freeze
  # Abas da página Saúde (produtividade vive no dashboard/hábitos, não ali).
  TABS = %w[health exam].freeze

  # Seções da aba "Sinais" (ordem de exibição). Chaves fora do catálogo caem em "other".
  SECTIONS = %w[sleep activity heart vitals body mobility workouts mind hearing nutrition other].freeze

  # Catálogo de métricas de SAÚDE (sinais). Exames vivem em ExamType/ExamResult.
  # As chaves de iPhone/Apple Watch vêm do app nativo (HealthCollector.swift) por
  # POST /api/metrics; a ordem aqui é a ordem de exibição dentro da seção.
  CATALOG = {
    # Sono (noite atribuída ao dia em que acorda)
    "sleep_minutes"        => { category: "health", unit: "min", section: "sleep" },
    "sleep_bedtime"        => { category: "health", unit: "hh:mm", section: "sleep" },
    "sleep_wake"           => { category: "health", unit: "hh:mm", section: "sleep" },
    "sleep_deep_minutes"   => { category: "health", unit: "min", section: "sleep" },
    "sleep_rem_minutes"    => { category: "health", unit: "min", section: "sleep" },
    "sleep_core_minutes"   => { category: "health", unit: "min", section: "sleep" },
    "sleep_awake_minutes"  => { category: "health", unit: "min", section: "sleep" },
    "sleep_in_bed_minutes" => { category: "health", unit: "min", section: "sleep" },
    "wrist_temperature"    => { category: "health", unit: "°C", section: "sleep" },
    "breathing_disturbances" => { category: "health", unit: "eventos/h", section: "sleep" },
    "nap_minutes"          => { category: "health", unit: "min", section: "sleep" },
    # Atividade (anéis do Watch: energia ativa, exercício, horas em pé)
    "steps"            => { category: "health", unit: "passos", section: "activity" },
    "active_energy"    => { category: "health", unit: "kcal", section: "activity" },
    "exercise_minutes" => { category: "health", unit: "min", section: "activity" },
    "stand_hours"      => { category: "health", unit: "h", section: "activity" },
    "stand_minutes"    => { category: "health", unit: "min", section: "activity" },
    "distance_km"      => { category: "health", unit: "km", section: "activity" },
    "flights_climbed"  => { category: "health", unit: "andares", section: "activity" },
    "basal_energy"     => { category: "health", unit: "kcal", section: "activity" },
    "cycling_km"       => { category: "health", unit: "km", section: "activity" },
    "swimming_m"       => { category: "health", unit: "m", section: "activity" },
    "daylight_minutes" => { category: "health", unit: "min", section: "activity" },
    "rings_closed"     => { category: "health", unit: "anéis", section: "activity" },
    "move_goal"        => { category: "health", unit: "kcal", section: "activity" },
    "exercise_goal"    => { category: "health", unit: "min", section: "activity" },
    "stand_goal"       => { category: "health", unit: "h", section: "activity" },
    # Coração
    "resting_hr" => { category: "health", unit: "bpm", section: "heart" },
    "hrv"        => { category: "health", unit: "ms", section: "heart" },
    "hr_avg"     => { category: "health", unit: "bpm", section: "heart" },
    "hr_min"     => { category: "health", unit: "bpm", section: "heart" },
    "hr_max"     => { category: "health", unit: "bpm", section: "heart" },
    "walking_hr" => { category: "health", unit: "bpm", section: "heart" },
    "vo2max"     => { category: "health", unit: "ml/kg·min", section: "heart" },
    "hr_recovery" => { category: "health", unit: "bpm", section: "heart" },
    "bp_systolic" => { category: "health", unit: "mmHg", section: "heart" },
    "bp_diastolic" => { category: "health", unit: "mmHg", section: "heart" },
    "afib_burden" => { category: "health", unit: "%", section: "heart" },
    "high_hr_events" => { category: "health", unit: "eventos", section: "heart" },
    "low_hr_events" => { category: "health", unit: "eventos", section: "heart" },
    "irregular_rhythm_events" => { category: "health", unit: "eventos", section: "heart" },
    "ecg_count"   => { category: "health", unit: "ECGs", section: "heart" },
    # Respiração e oxigenação
    "spo2"             => { category: "health", unit: "%", section: "vitals" },
    "respiratory_rate" => { category: "health", unit: "resp/min", section: "vitals" },
    "body_temperature" => { category: "health", unit: "°C", section: "vitals" },
    "blood_glucose"    => { category: "health", unit: "mg/dL", section: "vitals" },
    # Corpo (o peso em si mora em WeightEntry)
    "body_fat"  => { category: "health", unit: "%", section: "body" },
    "lean_mass" => { category: "health", unit: "kg", section: "body" },
    "body_bmi"  => { category: "health", unit: "kg/m²", section: "body" },
    # Mobilidade e corrida
    "walking_speed"         => { category: "health", unit: "km/h", section: "mobility" },
    "walking_step_length"   => { category: "health", unit: "cm", section: "mobility" },
    "walking_asymmetry"     => { category: "health", unit: "%", section: "mobility" },
    "walking_double_support" => { category: "health", unit: "%", section: "mobility" },
    "walking_steadiness"    => { category: "health", unit: "%", section: "mobility" },
    "stair_ascent_speed"    => { category: "health", unit: "m/s", section: "mobility" },
    "stair_descent_speed"   => { category: "health", unit: "m/s", section: "mobility" },
    "six_minute_walk"       => { category: "health", unit: "m", section: "mobility" },
    "running_speed"         => { category: "health", unit: "km/h", section: "mobility" },
    "running_power"         => { category: "health", unit: "W", section: "mobility" },
    "running_stride_length" => { category: "health", unit: "m", section: "mobility" },
    "running_vertical_oscillation" => { category: "health", unit: "cm", section: "mobility" },
    "running_ground_contact" => { category: "health", unit: "ms", section: "mobility" },
    # Treinos (totais do dia; cada treino mora em Workout)
    "workout_minutes" => { category: "health", unit: "min", section: "workouts" },
    "workout_count"   => { category: "health", unit: "treinos", section: "workouts" },
    "workout_energy"  => { category: "health", unit: "kcal", section: "workouts" },
    # Mente
    "mindful_minutes" => { category: "health", unit: "min", section: "mind" },
    "mood_valence"    => { category: "health", unit: "humor", section: "mind" },
    # Audição
    "env_audio_db"       => { category: "health", unit: "dB", section: "hearing" },
    "headphone_audio_db" => { category: "health", unit: "dB", section: "hearing" },
    # Nutrição (registros manuais ou de outros apps)
    "water_ml"       => { category: "health", unit: "ml", section: "nutrition" },
    "caffeine_mg"    => { category: "health", unit: "mg", section: "nutrition" },
    "dietary_energy" => { category: "health", unit: "kcal", section: "nutrition" },
    "protein_g"      => { category: "health", unit: "g", section: "nutrition" },
    "carbs_g"        => { category: "health", unit: "g", section: "nutrition" },
    "fat_g"          => { category: "health", unit: "g", section: "nutrition" },
    "github_contributions" => { category: "productivity", unit: "contributions" }
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

  # Seção de exibição da chave na aba "Sinais".
  def self.section(key)
    meta(key)[:section] || "other"
  end

  # Posição da chave no catálogo (ordem de exibição); desconhecidas vão para o fim.
  def self.catalog_position(key)
    CATALOG.keys.index(key.to_s) || CATALOG.size
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
  DURATION_KEYS = %w[
    sleep_minutes sleep_deep_minutes sleep_rem_minutes sleep_core_minutes sleep_awake_minutes
    sleep_in_bed_minutes nap_minutes exercise_minutes stand_minutes daylight_minutes workout_minutes
    mindful_minutes exercise_goal
  ].freeze

  # Para estas chaves, um valor MENOR é o sentido "bom" (seta verde ao cair).
  LOWER_IS_BETTER = %w[
    resting_hr hr_avg sleep_awake_minutes breathing_disturbances afib_burden high_hr_events low_hr_events
    irregular_rhythm_events env_audio_db headphone_audio_db walking_asymmetry walking_double_support
    bp_systolic bp_diastolic
  ].freeze
  # Chaves sem sentido bom/ruim: a variação aparece neutra (cinza).
  NEUTRAL_TREND = %w[
    sleep_bedtime sleep_wake wrist_temperature body_temperature blood_glucose body_fat lean_mass body_bmi
    move_goal exercise_goal stand_goal hr_min hr_max basal_energy caffeine_mg dietary_energy protein_g carbs_g
    fat_g running_ground_contact running_vertical_oscillation running_stride_length walking_step_length
    mood_valence ecg_count
  ].freeze

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
    self.class.format_value(key, value)
  end

  def duration_label
    self.class.format_value(key, value)
  end

  # Formata um valor de qualquer chave (usado também para médias).
  def self.format_value(key, value)
    return value if value.nil?

    key = key.to_s
    return format("%02d:%02d", value.to_i / 60, value.to_i % 60) if TIME_KEYS.include?(key)

    if DURATION_KEYS.include?(key)
      minutes = value.round
      return minutes >= 60 ? "#{minutes / 60}h #{minutes % 60}min" : "#{minutes}min"
    end

    number = value.to_f
    number = number.abs >= 100 ? number.round : number.round(1)
    number == number.to_i ? number.to_i : number
  end

  def self.self_explanatory?(key)
    TIME_KEYS.include?(key.to_s) || DURATION_KEYS.include?(key.to_s)
  end
end
