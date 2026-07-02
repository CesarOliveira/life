# Item do catálogo de exames (analito): chave canônica, nome/descrição i18n,
# grupo e apelidos (termos que o laudo usa — guiam a extração do PDF).
# SEM faixa de referência: ela pertence a cada resultado (vem do laudo ou não).
class ExamType < ApplicationRecord
  belongs_to :exam_group
  has_many :exam_results, dependent: :destroy

  validates :key, presence: true, uniqueness: true,
                  format: { with: /\A[a-z0-9_]+\z/, message: :invalid }
  validates :name_pt, :name_en, presence: true

  scope :ordered, -> { joins(:exam_group).order("exam_groups.position", :position, :id) }

  def name
    I18n.locale.to_s.start_with?("pt") ? name_pt : name_en.presence || name_pt
  end

  # Apelidos como texto (para forms): "tgo, ast, transaminase...".
  def aliases_text
    aliases.join(", ")
  end

  def aliases_text=(value)
    self.aliases = value.to_s.split(/[,;\n]/).map(&:strip).reject(&:blank?).uniq
  end

  def description
    I18n.locale.to_s.start_with?("pt") ? description_pt : description_en.presence || description_pt
  end

  # Lista "key: Nome (apelidos)" agrupada — referência para o extrator de PDF.
  def self.prompt_reference
    ExamGroup.ordered.includes(:exam_types).map do |group|
      lines = group.exam_types.map { |t| "  #{t.key}: #{t.name_pt} (#{t.aliases.join('; ')})" }
      "#{group.name_pt}:\n#{lines.join("\n")}"
    end.join("\n")
  end
end
