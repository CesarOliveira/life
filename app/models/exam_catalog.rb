# Catálogo curado de exames laboratoriais (pt-BR), organizado em PAINÉIS
# (grupos) com analitos. Cada analito tem chave canônica, nome, unidade, faixa
# de referência padrão (adulto) e "apelidos" — termos/abreviações que o laudo
# pode usar (ex.: "TGO", "AST", "Transaminase Glutâmica Oxalacética"), para o
# extrator de PDF mapear corretamente.
#
# A faixa do laudo, quando presente, tem prioridade sobre a daqui (o extrator a
# captura). Aqui é o fallback + a taxonomia (nome/unidade/painel/apelidos).
module ExamCatalog
  # Ordem importa (define a ordem de exibição dos painéis).
  PANELS = [
    {
      key: "hemograma", label: "Hemograma",
      analytes: [
        { key: "hemacias", label: "Hemácias", unit: "milhões/mm³", ref_low: 4.3, ref_high: 6.0, aliases: ["hemacias", "eritrocitos", "red blood cells", "rbc"] },
        { key: "hemoglobina", label: "Hemoglobina", unit: "g/dL", ref_low: 13.5, ref_high: 17.8, aliases: ["hemoglobina", "hb", "hgb", "hemoglobin"] },
        { key: "hematocrito", label: "Hematócrito", unit: "%", ref_low: 41, ref_high: 54, aliases: ["hematocrito", "ht", "hct", "hematocrit"] },
        { key: "vcm", label: "VCM", unit: "fL", ref_low: 80, ref_high: 100, aliases: ["vcm", "v.c.m", "mcv", "volume corpuscular medio"] },
        { key: "hcm", label: "HCM", unit: "pg", ref_low: 27, ref_high: 33, aliases: ["hcm", "h.c.m", "mch"] },
        { key: "chcm", label: "CHCM", unit: "g/dL", ref_low: 32, ref_high: 36, aliases: ["chcm", "c.h.c.m", "mchc"] },
        { key: "rdw", label: "RDW", unit: "%", ref_low: 11, ref_high: 14.5, aliases: ["rdw", "r.d.w"] },
        { key: "leucocitos", label: "Leucócitos", unit: "/mm³", ref_low: 3600, ref_high: 11_000, aliases: ["leucocitos", "leucograma", "white blood cells", "wbc"] },
        { key: "neutrofilos", label: "Neutrófilos (segmentados)", unit: "%", ref_low: 40, ref_high: 78, aliases: ["segmentados", "neutrofilos", "neutrophils", "neutrophils abs"] },
        { key: "bastonetes", label: "Bastonetes", unit: "%", ref_low: 0, ref_high: 5, aliases: ["bastonetes", "bands"] },
        { key: "eosinofilos", label: "Eosinófilos", unit: "%", ref_low: 1, ref_high: 5, aliases: ["eosinofilos", "eosinophils", "eosinophils abs"] },
        { key: "basofilos", label: "Basófilos", unit: "%", ref_low: 0, ref_high: 2, aliases: ["basofilos", "basophils", "basophils abs"] },
        { key: "linfocitos", label: "Linfócitos", unit: "%", ref_low: 20, ref_high: 50, aliases: ["linfocitos", "lymphocytes", "lymphocytes abs"] },
        { key: "monocitos", label: "Monócitos", unit: "%", ref_low: 2, ref_high: 10, aliases: ["monocitos", "monocytes", "monocytes abs"] },
        { key: "mielocitos", label: "Mielócitos", unit: "%", ref_low: 0, ref_high: 0, aliases: ["mielocitos", "myelocytes"] },
        { key: "metamielocitos", label: "Metamielócitos", unit: "%", ref_low: 0, ref_high: 0, aliases: ["metamielocitos", "metamyelocytes"] },
        { key: "plaquetas", label: "Plaquetas", unit: "/mm³", ref_low: 140_000, ref_high: 400_000, aliases: ["plaquetas", "platelets", "plt"] }
      ]
    },
    {
      key: "lipidograma", label: "Colesterol e frações",
      analytes: [
        { key: "cholesterol_total", label: "Colesterol total", unit: "mg/dL", ref_high: 190, aliases: ["colesterol total", "total cholesterol"] },
        { key: "hdl", label: "HDL", unit: "mg/dL", ref_low: 40, aliases: ["colesterol hdl", "hdl"] },
        { key: "ldl", label: "LDL", unit: "mg/dL", ref_high: 130, aliases: ["colesterol ldl", "ldl"] },
        { key: "vldl", label: "VLDL", unit: "mg/dL", ref_high: 40, aliases: ["colesterol vldl", "vldl"] },
        { key: "triglycerides", label: "Triglicérides", unit: "mg/dL", ref_high: 150, aliases: ["triglicerides", "triglicerideos", "triglycerides", "tg"] },
        { key: "castelli_1", label: "Índice de Castelli I", unit: "", ref_high: 4.9, aliases: ["indice de castelli i", "castelli i"] },
        { key: "castelli_2", label: "Índice de Castelli II", unit: "", ref_high: 3.3, aliases: ["indice de castelli ii", "castelli ii"] }
      ]
    },
    {
      key: "glicemia", label: "Glicemia",
      analytes: [
        { key: "glucose", label: "Glicose", unit: "mg/dL", ref_low: 70, ref_high: 99, aliases: ["glicose", "glicemia", "glucose"] },
        { key: "hba1c", label: "Hemoglobina glicada (HbA1c)", unit: "%", ref_high: 5.7, aliases: ["hemoglobina glicosilada", "hemoglobina glicada", "hba1c", "a1c"] }
      ]
    },
    {
      key: "funcao_renal", label: "Função renal",
      analytes: [
        { key: "ureia", label: "Ureia", unit: "mg/dL", ref_low: 15, ref_high: 50, aliases: ["ureia", "urea", "bun"] },
        { key: "creatinina", label: "Creatinina", unit: "mg/dL", ref_low: 0.7, ref_high: 1.4, aliases: ["creatinina", "creatinine"] }
      ]
    },
    {
      key: "funcao_hepatica", label: "Função hepática",
      analytes: [
        { key: "ast", label: "TGO / AST", unit: "U/L", ref_low: 10, ref_high: 38, aliases: ["ast", "tgo", "transaminase glutamica oxalacetica", "aspartato aminotransferase"] },
        { key: "alt", label: "TGP / ALT", unit: "U/L", ref_low: 10, ref_high: 38, aliases: ["alt", "tgp", "transaminase glutamica piruvica", "alanina aminotransferase"] },
        { key: "ggt", label: "Gama GT", unit: "U/L", ref_low: 11, ref_high: 55, aliases: ["gama glutamil transferase", "gama gt", "ggt", "gamma gt"] }
      ]
    },
    {
      key: "proteinas", label: "Proteínas",
      analytes: [
        { key: "proteinas_totais", label: "Proteínas totais", unit: "g/dL", ref_low: 6.1, ref_high: 7.9, aliases: ["proteinas totais", "total protein"] },
        { key: "albumina", label: "Albumina", unit: "g/dL", ref_low: 3.5, ref_high: 4.8, aliases: ["albumina", "albumin"] },
        { key: "globulina", label: "Globulina", unit: "g/dL", ref_low: 1.0, ref_high: 3.0, aliases: ["globulina", "globulin"] },
        { key: "relacao_ag", label: "Relação A/G", unit: "", ref_low: 1.2, ref_high: 2.2, aliases: ["relacao a/g", "relacao ag", "a/g ratio"] }
      ]
    },
    {
      key: "eletrolitos", label: "Eletrólitos",
      analytes: [
        { key: "sodio", label: "Sódio", unit: "mEq/L", ref_low: 135, ref_high: 145, aliases: ["sodio", "sodium", "na"] },
        { key: "potassio", label: "Potássio", unit: "mEq/L", ref_low: 3.5, ref_high: 5.5, aliases: ["potassio", "potassium", "k"] }
      ]
    },
    {
      key: "tireoide", label: "Tireoide",
      analytes: [
        { key: "tsh", label: "TSH", unit: "µUI/mL", ref_low: 0.38, ref_high: 5.8, aliases: ["hormonio tireoestimulante", "tsh"] },
        { key: "t4_livre", label: "T4 livre", unit: "ng/dL", ref_low: 0.7, ref_high: 1.8, aliases: ["tiroxina livre", "t4 livre", "t4l", "free t4"] }
      ]
    },
    {
      key: "ferro", label: "Ferro",
      analytes: [
        { key: "ferro_serico", label: "Ferro sérico", unit: "µg/dL", ref_low: 40, ref_high: 180, aliases: ["ferro serico", "ferro", "iron", "fe"] },
        { key: "ferritina", label: "Ferritina", unit: "ng/mL", ref_low: 24, ref_high: 336, aliases: ["ferritina", "ferritin"] },
        { key: "transferrina", label: "Transferrina", unit: "mg/dL", ref_low: 200, ref_high: 360, aliases: ["transferrina", "transferrin"] }
      ]
    },
    {
      key: "vitaminas_minerais", label: "Vitaminas e minerais",
      analytes: [
        { key: "vitamin_d", label: "Vitamina D (25-OH)", unit: "ng/mL", ref_low: 30, ref_high: 100, aliases: ["vitamina d", "25 hidroxi", "vitamin d", "25-oh"] },
        { key: "vitamin_b12", label: "Vitamina B12", unit: "pg/mL", ref_low: 211, ref_high: 911, aliases: ["vitamina b12", "b12", "cobalamina"] },
        { key: "vitamin_c", label: "Vitamina C", unit: "mg/dL", ref_low: 0.4, ref_high: 1.5, aliases: ["vitamina c", "acido ascorbico", "vitamin c"] },
        { key: "zinco", label: "Zinco", unit: "µg/dL", ref_low: 46, ref_high: 150, aliases: ["zinco", "zinc", "zn"] },
        { key: "selenio", label: "Selênio", unit: "µg/L", ref_low: 20, ref_high: 190, aliases: ["selenio", "selenium", "se"] }
      ]
    }
  ].freeze

  # key -> analito (com :panel e :panel_label embutidos).
  ANALYTES = PANELS.each_with_object({}) do |panel, acc|
    panel[:analytes].each do |a|
      acc[a[:key]] = a.merge(panel: panel[:key], panel_label: panel[:label])
    end
  end.freeze

  def self.meta(key)
    ANALYTES[key.to_s]
  end

  def self.keys
    ANALYTES.keys
  end

  # Referência para o extrator: uma linha por analito com nome + apelidos.
  def self.prompt_reference
    PANELS.map do |panel|
      lines = panel[:analytes].map do |a|
        "  #{a[:key]}: #{a[:label]} (#{a[:aliases].join('; ')})"
      end
      "#{panel[:label]}:\n#{lines.join("\n")}"
    end.join("\n")
  end

  # Agrupa medições (de exame) por painel, na ordem de PANELS. Chaves fora do
  # catálogo caem em "Outros". Retorna [{key, label, groups:[medida-group]}].
  def self.group(measurement_groups)
    by_panel = measurement_groups.group_by { |g| meta(g[:key])&.dig(:panel) || "outros" }
    ordered = PANELS.map { |p| [p[:key], p[:label]] }
    ordered << ["outros", "Outros"] if by_panel.key?("outros")
    ordered.filter_map do |panel_key, panel_label|
      items = by_panel[panel_key]
      next if items.nil?

      order = (ANALYTES.values.select { |a| a[:panel] == panel_key }.map { |a| a[:key] })
      items = items.sort_by { |g| order.index(g[:key]) || 999 }
      { key: panel_key, label: panel_label, groups: items }
    end
  end
end
