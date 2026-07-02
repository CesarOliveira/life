# Catálogo de exames vira banco (editável no admin, i18n) e os exames do
# usuário ganham model própria:
# - exam_groups: grupo/painel (Hemograma, Lipidograma...) — nome/descrição i18n.
# - exam_types:  item do catálogo (key canônica, nome/descrição i18n, grupo,
#                apelidos p/ extração). SEM faixa de referência (ela é por registro).
# - exam_results: exames do usuário (valor, unidade, data, ref_low/ref_high do
#                laudo — ou vazios). Migra os measurements categoria "exam".
class CreateExamCatalogAndResults < ActiveRecord::Migration[8.1]
  # Seed do catálogo atual (nomes PT/EN; apelidos usados pelo extrator).
  SEED = [
    ["hemograma", "Hemograma", "Complete blood count", [
      ["hemacias", "Hemácias", "Red blood cells", %w[hemacias eritrocitos rbc], "red blood cells"],
      ["hemoglobina", "Hemoglobina", "Hemoglobin", %w[hemoglobina hb hgb hemoglobin], nil],
      ["hematocrito", "Hematócrito", "Hematocrit", %w[hematocrito ht hct hematocrit], nil],
      ["vcm", "VCM", "MCV", ["vcm", "v.c.m", "mcv", "volume corpuscular medio"], nil],
      ["hcm", "HCM", "MCH", ["hcm", "h.c.m", "mch"], nil],
      ["chcm", "CHCM", "MCHC", ["chcm", "c.h.c.m", "mchc"], nil],
      ["rdw", "RDW", "RDW", ["rdw", "r.d.w"], nil],
      ["leucocitos", "Leucócitos", "White blood cells", %w[leucocitos leucograma wbc], "white blood cells"],
      ["neutrofilos", "Neutrófilos (segmentados)", "Neutrophils (segmented)", %w[segmentados neutrofilos neutrophils], "neutrophils abs"],
      ["bastonetes", "Bastonetes", "Bands", %w[bastonetes bands], nil],
      ["eosinofilos", "Eosinófilos", "Eosinophils", %w[eosinofilos eosinophils], "eosinophils abs"],
      ["basofilos", "Basófilos", "Basophils", %w[basofilos basophils], "basophils abs"],
      ["linfocitos", "Linfócitos", "Lymphocytes", %w[linfocitos lymphocytes], "lymphocytes abs"],
      ["monocitos", "Monócitos", "Monocytes", %w[monocitos monocytes], "monocytes abs"],
      ["mielocitos", "Mielócitos", "Myelocytes", %w[mielocitos myelocytes], nil],
      ["metamielocitos", "Metamielócitos", "Metamyelocytes", %w[metamielocitos metamyelocytes], nil],
      ["plaquetas", "Plaquetas", "Platelets", %w[plaquetas platelets plt], nil]
    ]],
    ["lipidograma", "Colesterol e frações", "Cholesterol panel", [
      ["cholesterol_total", "Colesterol total", "Total cholesterol", ["colesterol total", "total cholesterol"], nil],
      ["hdl", "HDL", "HDL", ["colesterol hdl", "hdl"], nil],
      ["ldl", "LDL", "LDL", ["colesterol ldl", "ldl"], nil],
      ["vldl", "VLDL", "VLDL", ["colesterol vldl", "vldl"], nil],
      ["triglycerides", "Triglicérides", "Triglycerides", %w[triglicerides triglicerideos triglycerides tg], nil],
      ["castelli_1", "Índice de Castelli I", "Castelli index I", ["indice de castelli i", "castelli i"], nil],
      ["castelli_2", "Índice de Castelli II", "Castelli index II", ["indice de castelli ii", "castelli ii"], nil]
    ]],
    ["glicemia", "Glicemia", "Blood sugar", [
      ["glucose", "Glicose", "Glucose", %w[glicose glicemia glucose], nil],
      ["hba1c", "Hemoglobina glicada (HbA1c)", "Glycated hemoglobin (HbA1c)", ["hemoglobina glicosilada", "hemoglobina glicada", "hba1c", "a1c"], nil]
    ]],
    ["funcao_renal", "Função renal", "Kidney function", [
      ["ureia", "Ureia", "Urea", %w[ureia urea bun], nil],
      ["creatinina", "Creatinina", "Creatinine", %w[creatinina creatinine], nil]
    ]],
    ["funcao_hepatica", "Função hepática", "Liver function", [
      ["ast", "TGO / AST", "AST (SGOT)", ["ast", "tgo", "transaminase glutamica oxalacetica", "aspartato aminotransferase"], nil],
      ["alt", "TGP / ALT", "ALT (SGPT)", ["alt", "tgp", "transaminase glutamica piruvica", "alanina aminotransferase"], nil],
      ["ggt", "Gama GT", "Gamma-GT", ["gama glutamil transferase", "gama gt", "ggt", "gamma gt"], nil]
    ]],
    ["proteinas", "Proteínas", "Proteins", [
      ["proteinas_totais", "Proteínas totais", "Total protein", ["proteinas totais", "total protein"], nil],
      ["albumina", "Albumina", "Albumin", %w[albumina albumin], nil],
      ["globulina", "Globulina", "Globulin", %w[globulina globulin], nil],
      ["relacao_ag", "Relação A/G", "A/G ratio", ["relacao a/g", "relacao ag", "a/g ratio"], nil]
    ]],
    ["eletrolitos", "Eletrólitos", "Electrolytes", [
      ["sodio", "Sódio", "Sodium", %w[sodio sodium na], nil],
      ["potassio", "Potássio", "Potassium", %w[potassio potassium k], nil]
    ]],
    ["tireoide", "Tireoide", "Thyroid", [
      ["tsh", "TSH", "TSH", ["hormonio tireoestimulante", "tsh"], nil],
      ["t4_livre", "T4 livre", "Free T4", ["tiroxina livre", "t4 livre", "t4l", "free t4"], nil]
    ]],
    ["ferro", "Ferro", "Iron", [
      ["ferro_serico", "Ferro sérico", "Serum iron", ["ferro serico", "ferro", "iron", "fe"], nil],
      ["ferritina", "Ferritina", "Ferritin", %w[ferritina ferritin], nil],
      ["transferrina", "Transferrina", "Transferrin", %w[transferrina transferrin], nil]
    ]],
    ["vitaminas_minerais", "Vitaminas e minerais", "Vitamins & minerals", [
      ["vitamin_d", "Vitamina D (25-OH)", "Vitamin D (25-OH)", ["vitamina d", "25 hidroxi", "vitamin d", "25-oh"], nil],
      ["vitamin_b12", "Vitamina B12", "Vitamin B12", ["vitamina b12", "b12", "cobalamina"], nil],
      ["vitamin_c", "Vitamina C", "Vitamin C", ["vitamina c", "acido ascorbico", "vitamin c"], nil],
      ["zinco", "Zinco", "Zinc", %w[zinco zinc zn], nil],
      ["selenio", "Selênio", "Selenium", %w[selenio selenium se], nil]
    ]]
  ].freeze

  class MigGroup < ActiveRecord::Base
    self.table_name = "exam_groups"
  end

  class MigType < ActiveRecord::Base
    self.table_name = "exam_types"
  end

  class MigResult < ActiveRecord::Base
    self.table_name = "exam_results"
  end

  class MigMeasurement < ActiveRecord::Base
    self.table_name = "measurements"
  end

  def up
    create_tables
    seed_catalog
    migrate_existing_exams
  end

  def down
    drop_table :exam_results
    drop_table :exam_types
    drop_table :exam_groups
  end

  private

  def create_tables
    create_table :exam_groups do |t|
      t.string :key, null: false
      t.string :name_pt, null: false
      t.string :name_en, null: false
      t.text :description_pt
      t.text :description_en
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index :key, unique: true
    end

    create_table :exam_types do |t|
      t.references :exam_group, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name_pt, null: false
      t.string :name_en, null: false
      t.text :description_pt
      t.text :description_en
      t.string :aliases, array: true, default: [], null: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index :key, unique: true
    end

    create_table :exam_results do |t|
      t.references :account, null: false, foreign_key: true
      t.references :exam_type, null: false, foreign_key: true
      t.decimal :value, precision: 12, scale: 3, null: false
      t.string :unit
      t.date :measured_on, null: false
      t.decimal :ref_low, precision: 12, scale: 3   # do laudo (ou manual); pode faltar
      t.decimal :ref_high, precision: 12, scale: 3  # do laudo (ou manual); pode faltar
      t.string :source, null: false, default: "manual"
      t.timestamps
      t.index [:account_id, :exam_type_id, :measured_on], unique: true, name: "idx_exam_results_unique"
    end
  end

  def seed_catalog
    SEED.each_with_index do |(gkey, gpt, gen, types), gi|
      group = MigGroup.create!(key: gkey, name_pt: gpt, name_en: gen, position: gi)
      types.each_with_index do |(key, name_pt, name_en, aliases, extra_alias), ti|
        MigType.create!(exam_group_id: group.id, key: key, name_pt: name_pt, name_en: name_en,
                        aliases: (aliases + [extra_alias]).compact.uniq, position: ti)
      end
    end
  end

  # Move os measurements categoria "exam" para exam_results (por key) e os
  # remove de measurements. Chaves fora do catálogo vão para o grupo "outros".
  def migrate_existing_exams
    types = MigType.all.index_by(&:key)
    outros = nil

    MigMeasurement.where(category: "exam").find_each do |m|
      type = types[m.key]
      if type.nil?
        outros ||= MigGroup.find_or_create_by!(key: "outros") do |g|
          g.name_pt = "Outros"
          g.name_en = "Other"
          g.position = 99
        end
        type = MigType.create!(exam_group_id: outros.id, key: m.key,
                               name_pt: m.key.humanize, name_en: m.key.humanize, aliases: [m.key])
        types[m.key] = type
      end

      MigResult.find_or_create_by!(account_id: m.account_id, exam_type_id: type.id, measured_on: m.measured_on) do |r|
        r.value = m.value
        r.unit = m.unit
        r.ref_low = m.ref_low
        r.ref_high = m.ref_high
        r.source = m.source
      end
    end

    MigMeasurement.where(category: "exam").delete_all
  end
end
