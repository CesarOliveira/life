# Grupo/painel de exames (Hemograma, Lipidograma, ...). Nomes/descrições
# internacionalizados por coluna (pt/en) e editáveis no admin.
# == Schema Information
#
# Table name: exam_groups
#
#  id             :bigint           not null, primary key
#  description_en :text
#  description_pt :text
#  favorite       :boolean          default(FALSE), not null
#  key            :string           not null
#  name_en        :string           not null
#  name_pt        :string           not null
#  position       :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_exam_groups_on_key  (key) UNIQUE
#
class ExamGroup < ApplicationRecord
  has_many :exam_types, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :exam_group

  validates :key, presence: true, uniqueness: true
  validates :name_pt, :name_en, presence: true

  scope :ordered, -> { order(:position, :id) }
  # Favoritos primeiro (aba Exames), depois a ordem do catálogo.
  scope :favorites_first, -> { order(favorite: :desc, position: :asc, id: :asc) }

  def name
    I18n.locale.to_s.start_with?("pt") ? name_pt : name_en.presence || name_pt
  end

  def description
    I18n.locale.to_s.start_with?("pt") ? description_pt : description_en.presence || description_pt
  end
end
