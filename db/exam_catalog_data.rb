# Dados do catálogo de exames (grupos/tipos) — usados pelo db/seeds.rb para
# ambientes novos. Em produção o catálogo já foi criado pela migration e é
# gerido pelo /admin (este arquivo NÃO sobrescreve mudanças feitas lá).
EXAM_CATALOG_DATA = [
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
