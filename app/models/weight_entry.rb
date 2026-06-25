class WeightEntry < ApplicationRecord
  belongs_to :account

  validates :date, presence: true, uniqueness: { scope: :account_id }
  validates :weight_kg, presence: true,
            numericality: { greater_than: 0, less_than: 1000 }

  scope :chronological, -> { order(:date) }
  scope :recent_first, -> { order(date: :desc) }

  # IMC = peso(kg) / altura(m)². Precisa da altura da conta.
  def bmi
    height = account&.height_cm.to_i
    return nil if height <= 0

    (weight_kg.to_f / ((height / 100.0)**2)).round(1)
  end

  # Faixa do IMC (OMS): :underweight, :normal, :overweight, :obese.
  def bmi_category
    value = bmi
    return nil if value.nil?

    case value
    when ...18.5 then :underweight
    when 18.5...25 then :normal
    when 25...30 then :overweight
    else :obese
    end
  end
end
