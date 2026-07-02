# One-off (remover após rodar — ver DEPLOY_OPERACOES.md §2): compara os exames
# importados em produção com os valores do laudo (PDF Resultado0050099,
# coleta 10/02/2026) e imprime um diagnóstico nos logs de deploy.
EXPECTED = {
  "cholesterol_total" => [190, nil, 190], "hdl" => [53, 45, nil], "triglycerides" => [71, nil, 150],
  "ldl" => [122.8, nil, 100], "vldl" => [14.2, nil, 40], "castelli_1" => [3.6, nil, 4.9],
  "castelli_2" => [2.3, nil, 3.3], "glucose" => [101, 70, 99], "ureia" => [38, 15, 50],
  "creatinina" => [1.33, 0.7, 1.4], "ast" => [23, 10, 38], "alt" => [29, 10, 38],
  "ggt" => [16, 11, 55], "proteinas_totais" => [8.7, 6.1, 7.9], "albumina" => [5.66, 3.5, 4.8],
  "globulina" => [3.0, 1.0, 3.0], "relacao_ag" => [1.9, 1.2, 2.2], "sodio" => [139, 135, 145],
  "potassio" => [4.4, 3.5, 5.5], "tsh" => [1.97, 0.38, 5.8], "t4_livre" => [1.3, 0.7, 1.8],
  "vitamin_b12" => [685, 211, 911], "vitamin_d" => [60, 30, 100], "vitamin_c" => [1.1, 0.4, 1.5],
  "zinco" => [102, 46, 150], "ferro_serico" => [61.2, 40, 180], "ferritina" => [265, 24, 336],
  "transferrina" => [247, 200, 360], "hba1c" => [5.7, 5, 7], "selenio" => [85, 20, 190],
  "hemacias" => [4.79, 4.3, 6], "hemoglobina" => [14.6, 13.5, 17.8], "hematocrito" => [42.3, 41, 54],
  "vcm" => [88.31, 80, 100], "hcm" => [30.48, 27, 33], "chcm" => [34.52, 32, 36],
  "rdw" => [13.5, 11, 14.5], "leucocitos" => [5410, 3600, 11_000], "mielocitos" => [0, 0, 0],
  "metamielocitos" => [0, 0, 0], "bastonetes" => [0, 0, 5], "neutrofilos" => [55, 40, 78],
  "eosinofilos" => [2, 1, 5], "basofilos" => [0, 0, 2], "linfocitos" => [38, 20, 50],
  "monocitos" => [5, 2, 10], "plaquetas" => [201_000, 140_000, 400_000]
}.freeze

begin
  close = ->(a, b) { !a.nil? && !b.nil? && (a.to_f - b.to_f).abs < 0.01 }
  exams = Measurement.exams.to_a
  by_key = exams.group_by(&:key)
  puts "[compare] producao=#{exams.size} exames (#{by_key.size} chaves) | PDF=#{EXPECTED.size}"

  problems = []
  refs = []
  EXPECTED.each do |key, (val, lo, hi)|
    rows = by_key[key]
    next problems << "FALTA #{key} (PDF: #{val})" if rows.nil?

    m = rows.max_by(&:measured_on)
    problems << "VALOR #{key}=#{m.value.to_f} (PDF: #{val})" unless close.call(m.value, val)
    problems << "DATA #{key}=#{m.measured_on} (PDF: 2026-02-10)" unless m.measured_on == Date.new(2026, 2, 10)
    ref_mismatch = (!lo.nil? && !close.call(m.ref_low, lo)) || (!hi.nil? && !close.call(m.ref_high, hi))
    refs << "REF #{key} api=(#{m.ref_low&.to_f}-#{m.ref_high&.to_f}) pdf=(#{lo}-#{hi})" if ref_mismatch
  end
  extras = by_key.keys - EXPECTED.keys
  extras.each { |k| puts "[compare] EXTRA #{k} -> #{by_key[k].map { |m| "#{m.value.to_f}@#{m.measured_on}" }.join(', ')}" }
  problems.each { |p| puts "[compare] #{p}" }
  refs.each { |r| puts "[compare] #{r}" }
  puts problems.empty? ? "[compare] VALORES/DATAS OK" : "[compare] #{problems.size} problemas"
rescue StandardError => e
  puts "[compare] ERRO #{e.class}: #{e.message}"
end
