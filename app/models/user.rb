# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string           default(""), not null
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }

  # Roles da plataforma (muitas por usuário, via Role + join). Substituem o antigo
  # PLATFORM_ADMIN_EMAILS — a ENV agora só faz bootstrap na migration de dados.
  def role?(name)
    name = name.to_s
    if roles.loaded?
      roles.any? { |r| r.name == name }
    else
      roles.exists?(name: name)
    end
  end

  def add_role(name)
    return if role?(name)
    roles << Role.find_or_create_by!(name: name.to_s)
  end

  def remove_role(name)
    to_remove = roles.where(name: name.to_s).to_a
    roles.delete(*to_remove) if to_remove.any?
  end

  # Admin da plataforma = tem a role "admin" (acesso ao /admin).
  def platform_admin?
    role?(Role::ADMIN)
  end

  # Super admin = tem a role "super_admin" (acesso ao ActiveAdmin em /super_admin).
  def super_admin?
    role?(Role::SUPER_ADMIN)
  end

  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :owned_accounts, class_name: "Account", foreign_key: :owner_id, dependent: :nullify
  has_and_belongs_to_many :roles

  # Cria ou vincula um usuário a partir do payload do OmniAuth (Google).
  # O Google entrega e-mail verificado, então vincular por e-mail a um cadastro
  # já existente (feito por senha) é seguro.
  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    email = auth.info.email
    if (user = find_by(email: email))
      user.update(provider: auth.provider, uid: auth.uid)
    else
      user = create(
        provider: auth.provider,
        uid: auth.uid,
        email: email,
        name: auth.info.name.presence || email.to_s.split("@").first,
        password: Devise.friendly_token[0, 24]
      )
    end
    user
  end

  # Contas em que o usuário tem vínculo ativo (aprovado).
  def active_accounts
    accounts.merge(Membership.active)
  end

  def membership_for(account)
    return nil unless account
    memberships.find_by(account_id: account.id)
  end

  def member_of?(account)
    membership_for(account)&.active? || false
  end

  def admin_of?(account)
    m = membership_for(account)
    m.present? && m.active? && m.admin?
  end
end
