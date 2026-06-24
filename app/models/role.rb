# == Schema Information
#
# Table name: roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_roles_on_name  (name) UNIQUE
#
class Role < ApplicationRecord
  has_and_belongs_to_many :users

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Roles pré-definidas. Outras podem ser criadas sob demanda (são apenas dados).
  ADMIN       = "admin".freeze
  SUPER_ADMIN = "super_admin".freeze
  MEMBER      = "member".freeze
  KNOWN       = [SUPER_ADMIN, ADMIN, MEMBER].freeze
end
