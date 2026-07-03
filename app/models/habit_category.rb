# Categoria de hábito por conta (ex.: Saúde, Performance, Mente,
# Relacionamentos) — no máximo 10 por conta. Alimenta o radar de atividade.
# == Schema Information
#
# Table name: habit_categories
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_habit_categories_on_account_id           (account_id)
#  index_habit_categories_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class HabitCategory < ApplicationRecord
  MAX_PER_ACCOUNT = 10

  belongs_to :account
  has_many :habits, dependent: :nullify

  validates :name, presence: true, length: { maximum: 40 },
                   uniqueness: { scope: :account_id }
  validate :under_limit, on: :create

  scope :ordered, -> { order(:position, :id) }

  private

  def under_limit
    return if account.nil? || account.habit_categories.count < MAX_PER_ACCOUNT

    errors.add(:base, :limit_reached)
  end
end
