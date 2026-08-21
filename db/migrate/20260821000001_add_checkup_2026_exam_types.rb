# Exames do check-up de ago/2026 que faltavam no catálogo (o extractor de PDF
# ignora analitos fora do catálogo — por isso "sumiram" do import): ácido
# fólico, insulina, testosterona total/livre, lipoproteína (a), apolipoproteína
# B e PCR ultrassensível. Idempotente — não mexe no que o admin já tiver
# criado/renomeado.
class AddCheckup2026ExamTypes < ActiveRecord::Migration[8.1]
  class MigGroup < ActiveRecord::Base
    self.table_name = "exam_groups"
  end

  class MigType < ActiveRecord::Base
    self.table_name = "exam_types"
  end

  NEW_GROUPS = [
    ["hormonios", "Hormônios", "Hormones"]
  ].freeze

  NEW_TYPES = [
    ["acido_folico", "vitaminas_minerais", "Ácido fólico", "Folate",
     ["acido folico", "ácido fólico", "folato", "folic acid", "vitamina b9"]],
    ["insulina", "glicemia", "Insulina", "Insulin",
     ["insulina", "insulin", "insulina basal", "insulina de jejum"]],
    ["testosterona_total", "hormonios", "Testosterona total", "Total testosterone",
     ["testosterona total", "testosterona", "total testosterone"]],
    ["testosterona_livre", "hormonios", "Testosterona livre", "Free testosterone",
     ["testosterona livre", "free testosterone"]],
    ["lipoproteina_a", "lipidograma", "Lipoproteína (a)", "Lipoprotein (a)",
     ["lipoproteina a", "lipoproteína (a)", "lpa", "lp(a)"]],
    ["apolipoproteina_b", "lipidograma", "Apolipoproteína B", "Apolipoprotein B",
     ["apolipoproteina b", "apolipoproteína b", "apo b", "apob"]],
    ["pcr_us", "marcadores", "PCR ultrassensível", "hs-CRP",
     ["proteina c reativa ultrassensivel", "proteína c reativa", "pcr ultrassensível",
      "pcr-us", "pcr", "hs-crp"]]
  ].freeze

  def up
    NEW_GROUPS.each do |key, pt, en|
      next if MigGroup.exists?(key: key)

      position = MigGroup.maximum(:position).to_i + 1
      MigGroup.create!(key: key, name_pt: pt, name_en: en, position: position)
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
