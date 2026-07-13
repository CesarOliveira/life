# == Schema Information
#
# Table name: accounts
#
#  id         :bigint           not null, primary key
#  api_token  :string
#  height_cm  :integer
#  join_code  :string
#  locale     :string           default("pt-BR"), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_accounts_on_api_token  (api_token) UNIQUE
#  index_accounts_on_join_code  (join_code) UNIQUE
#  index_accounts_on_owner_id   (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
class Account < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :habits, dependent: :destroy
  has_many :weight_entries, dependent: :destroy
  has_many :app_usages, dependent: :destroy
  has_many :measurements, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :exam_extractions, dependent: :destroy
  has_many :exam_results, dependent: :destroy
  has_many :habit_categories, dependent: :destroy
  has_many :connectors, dependent: :destroy

  LOCALES = %w[pt-BR en].freeze
  validates :locale, inclusion: { in: LOCALES }

  after_create :seed_default_habit_categories

  # Token pessoal para a API de ingestão (ex.: script do Mac enviando uso por app).
  has_secure_token :api_token

  validates :name, presence: true
  validates :join_code, uniqueness: true, allow_nil: true

  before_create :ensure_join_code

  # Garante a conta pessoal do usuário (modelo single-user), com token gerado.
  # Reusado pelo 1º acesso web (ensure_personal_account) e pelo login do app.
  def self.ensure_personal_for(user, locale: "pt-BR")
    existing = user.accounts.first
    return existing if existing

    loc = LOCALES.include?(locale.to_s) ? locale.to_s : "pt-BR"
    account = user.owned_accounts.create!(
      name: user.name.presence || I18n.t("accounts.personal_name"),
      locale: loc
    )
    user.memberships.create!(account: account, role: "owner", status: "active")
    account
  end

  def admin_memberships
    memberships.where(role: %w[owner admin], status: "active")
  end

  def pending_memberships
    memberships.where(status: "pending")
  end

  private

  def ensure_join_code
    return if join_code.present?

    loop do
      self.join_code = SecureRandom.hex(5)
      break unless Account.exists?(join_code: join_code)
    end
  end
  # Categorias padrão POR IDIOMA (definidas na criação da conta, conforme o
  # idioma escolhido no cadastro). Renomeáveis; até 10 no total.
  DEFAULT_HABIT_CATEGORIES = {
    "pt-BR" => %w[Saúde Performance Mente Relacionamentos],
    "en" => %w[Health Performance Mind Relationships]
  }.freeze

  def seed_default_habit_categories
    names = DEFAULT_HABIT_CATEGORIES[locale] || DEFAULT_HABIT_CATEGORIES["pt-BR"]
    names.each_with_index do |name, i|
      habit_categories.create!(name: name, position: i)
    end
  end
end
