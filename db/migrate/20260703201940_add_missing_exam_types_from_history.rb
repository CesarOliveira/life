# Exames presentes no histórico de laudos (2021-2025) que faltavam no catálogo:
# ácido úrico, CPK, homocisteína e PSA (total/livre). Idempotente — não mexe no
# que o admin já tiver criado/renomeado.
class AddMissingExamTypesFromHistory < ActiveRecord::Migration[8.1]
  class MigGroup < ActiveRecord::Base
    self.table_name = "exam_groups"
  end

  class MigType < ActiveRecord::Base
    self.table_name = "exam_types"
  end

  NEW_GROUPS = [
    ["prostata", "Próstata", "Prostate", 10],
    ["marcadores", "Outros marcadores", "Other markers", 11]
  ].freeze

  NEW_TYPES = [
    ["acido_urico", "funcao_renal", "Ácido úrico", "Uric acid",
     ["acido urico", "ácido úrico", "uric acid", "urato"]],
    ["psa_total", "prostata", "PSA total", "Total PSA",
     ["psa total", "psa", "antigeno prostatico especifico"]],
    ["psa_livre", "prostata", "PSA livre", "Free PSA",
     ["psa livre", "free psa"]],
    ["cpk", "marcadores", "CPK (creatinofosfoquinase)", "CPK (creatine kinase)",
     ["cpk", "c.p.k", "creatino fosfoquinase", "creatinofosfoquinase", "creatina quinase", "ck"]],
    ["homocisteina", "marcadores", "Homocisteína", "Homocysteine",
     ["homocisteina", "homocisteína", "homocysteine", "hcy"]]
  ].freeze

  def up
    NEW_GROUPS.each do |key, pt, en, pos|
      next if MigGroup.exists?(key: key)

      MigGroup.create!(key: key, name_pt: pt, name_en: en, position: pos)
    end

    NEW_TYPES.each do |key, group_key, pt, en, aliases|
      next if MigType.exists?(key: key)

      group = MigGroup.find_by!(key: group_key)
      position = MigType.where(exam_group_id: group.id).maximum(:position).to_i + 1
      MigType.create!(exam_group_id: group.id, key: key, name_pt: pt, name_en: en,
                      aliases: aliases, position: position)
    end
  end

  def down; end
end
