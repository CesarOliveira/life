# Grupo/painel de exames (Hemograma, Lipidograma, ...). Nomes/descrições
# internacionalizados por coluna (pt/en) e editáveis no admin.
class ExamGroup < ApplicationRecord
  has_many :exam_types, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :exam_group

  validates :key, presence: true, uniqueness: true
  validates :name_pt, :name_en, presence: true

  scope :ordered, -> { order(:position, :id) }

  def name
    I18n.locale.to_s.start_with?("pt") ? name_pt : name_en.presence || name_pt
  end

  def description
    I18n.locale.to_s.start_with?("pt") ? description_pt : description_en.presence || description_pt
  end
end
