require "net/http"
require "base64"
require "json"
require "stringio"
require "pdf/reader"

# Extrai resultados de um PDF de exame laboratorial e devolve linhas prontas
# para virar `Measurement` (categoria "exam"). Sem chave configurada, degrada
# com erro "not_configured". Requer ENV["ANTHROPIC_API_KEY"].
#
# Custo: primeiro extrai o TEXTO do PDF localmente (grátis) e manda só o texto
# para o Claude Haiku (barato). Se o Haiku não achar nada, ESCALA para o Sonnet
# (no texto) e, por fim, manda o PDF em imagem para o Sonnet (laudo escaneado).
# O PDF é processado em memória — não é persistido.
class ExamPdfExtractor
  Result = Struct.new(:rows, :measured_on, :error, :usage, keyword_init: true) do
    def ok?
      error.nil?
    end
  end

  API_URL = "https://api.anthropic.com/v1/messages"
  PRIMARY_MODEL = "claude-haiku-4-5-20251001".freeze # barato (texto)
  FALLBACK_MODEL = "claude-sonnet-4-6".freeze        # escala quando o Haiku falha

  # Preço por 1M de tokens (USD): [entrada, saída]. Para estimar o custo por import.
  PRICING = {
    PRIMARY_MODEL => [1.0, 5.0],
    FALLBACK_MODEL => [3.0, 15.0]
  }.freeze
  MAX_BYTES = 15 * 1024 * 1024
  MAX_OUTPUT = 4096       # tokens de saída (hemograma completo tem ~45 linhas)
  MAX_TEXT = 30_000       # chars de texto enviados ao modelo
  MIN_TEXT = 80           # abaixo disso, o PDF é imagem/escaneado -> vai pro Sonnet
  OPEN_TIMEOUT = 15
  READ_TIMEOUT = 120

  def self.configured?
    ENV["ANTHROPIC_API_KEY"].to_s.strip.present?
  end

  def initialize(data, today: Date.current)
    @data = data.to_s
    @today = today
  end

  def call
    return Result.new(error: "not_configured") unless self.class.configured?
    return Result.new(error: "empty") if @data.blank?
    return Result.new(error: "too_large") if @data.bytesize > MAX_BYTES

    @spent = [] # [model, input_tokens, output_tokens] por chamada à API
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    last = nil
    attempts.each do |model, content|
      last = safe_attempt(model, content)
      break if last&.rows&.any?
    end
    last ||= Result.new(error: "extraction_failed")
    last.usage = usage_summary(started)
    last
  end

  # Converte o JSON do modelo em linhas normalizadas (testável sem HTTP).
  def build_result(parsed)
    return Result.new(error: "extraction_failed") unless parsed.is_a?(Hash)

    measured_on = parse_date(parsed["measured_on"]) || @today
    results = parsed["results"]
    return Result.new(rows: [], measured_on: measured_on, error: "no_results") unless results.is_a?(Array) && results.any?

    rows = results.filter_map { |item| normalize(item, measured_on) }
    return Result.new(rows: [], measured_on: measured_on, error: "no_results") if rows.empty?

    Result.new(rows: rows, measured_on: measured_on)
  end

  private

  # Ordem de tentativas: [modelo, conteúdo]. Texto+Haiku primeiro (barato);
  # escala p/ Sonnet no texto; por fim Sonnet no PDF (imagem).
  def attempts
    text = extract_text
    list = []
    if text.length >= MIN_TEXT
      list << [PRIMARY_MODEL, text_content(text)]
      list << [FALLBACK_MODEL, text_content(text)]
    end
    list << [FALLBACK_MODEL, document_content]
    list
  end

  def safe_attempt(model, content)
    build_result(request_extraction(model, content))
  rescue Net::OpenTimeout, Net::ReadTimeout
    Result.new(error: "timeout")
  rescue StandardError => e
    Rails.logger.error("ExamPdfExtractor(#{model}): #{e.class}: #{e.message}")
    nil
  end

  # Texto do PDF (grátis). Vazio se o PDF não tiver camada de texto.
  def extract_text
    reader = PDF::Reader.new(StringIO.new(@data))
    reader.pages.map(&:text).join("\n").strip.first(MAX_TEXT)
  rescue StandardError
    ""
  end

  def text_content(text)
    [{ type: "text", text: "#{prompt}\n\n--- TEXTO DO LAUDO ---\n#{text}" }]
  end

  def document_content
    [
      { type: "document", source: { type: "base64", media_type: "application/pdf", data: Base64.strict_encode64(@data) } },
      { type: "text", text: prompt }
    ]
  end

  def normalize(item, default_date)
    return nil unless item.is_a?(Hash)

    key = item["key"].to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "").first(60).presence
    return nil if key.blank? || !numeric?(item["value"])

    meta = Measurement.meta(key)
    {
      key: key,
      value: numeric(item["value"]),
      unit: item["unit"].to_s.strip.first(20).presence || meta[:unit],
      measured_on: parse_date(item["measured_on"]) || default_date,
      category: "exam",
      ref_low: present_number(item["ref_low"]) || meta[:ref_low],
      ref_high: present_number(item["ref_high"]) || meta[:ref_high],
      source: "pdf"
    }
  end

  def request_extraction(model, content)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"
    request["content-type"] = "application/json"
    request.body = { model: model, max_tokens: MAX_OUTPUT, messages: [{ role: "user", content: content }] }.to_json

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.body}" unless response.code.to_i == 200

    body = JSON.parse(response.body)
    track_usage(model, body["usage"])
    extract_json(body)
  end

  def track_usage(model, usage)
    return unless usage.is_a?(Hash)

    @spent << [model, usage["input_tokens"].to_i, usage["output_tokens"].to_i] if @spent
  end

  # Resumo do gasto do import: modelos, tokens somados e custo estimado (USD).
  def usage_summary(started)
    cost = @spent.sum do |model, inp, out|
      inp_price, out_price = PRICING.fetch(model, [0, 0])
      ((inp * inp_price) + (out * out_price)) / 1_000_000.0
    end
    {
      file_bytes: @data.bytesize,
      models_used: @spent.map { |m, _, _| m[/haiku|sonnet|opus/] || m }.uniq.join(","),
      input_tokens: @spent.sum { |_, inp, _| inp },
      output_tokens: @spent.sum { |_, _, out| out },
      cost_usd: cost.round(6),
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    }
  end

  # Pega o texto da resposta do Claude e faz parse do JSON (tolera cercas ```json).
  def extract_json(response_body)
    text = Array(response_body["content"]).filter_map { |b| b["text"] }.join("\n")
    text = text.gsub(/```json\s*/i, "").gsub(/```/, "").strip
    JSON.parse(text)
  end

  def prompt
    <<~PROMPT
      Você recebe um exame laboratorial (pt-BR), como PDF ou texto. Extraia TODOS os resultados numéricos.
      Responda APENAS com JSON válido (sem markdown, sem comentários), neste formato:
      {"measured_on":"YYYY-MM-DD","results":[{"key":"glucose","value":92,"unit":"mg/dL","ref_low":70,"ref_high":99}]}

      Use SOMENTE as chaves canônicas abaixo (a coluna antes dos ":"). Cada linha traz
      o nome e, entre parênteses, os apelidos/termos que o laudo pode usar — mapeie por eles:

      #{ExamCatalog.prompt_reference}

      Regras:
      - "measured_on": data da coleta (ISO). Se houver datas diferentes por exame, use a mais comum.
      - Para o hemograma (série branca), use o valor em PORCENTAGEM (%) do diferencial
        (neutrofilos/segmentados, linfocitos, monocitos, eosinofilos, basofilos), não o absoluto.
      - "value": número com ponto decimal. SEMPRE inclua "unit" e a faixa de referência
        (ref_low/ref_high) EXATAMENTE como o laudo informa (preferir a do laudo à padrão).
      - Se um analito NÃO estiver na lista acima, IGNORE (não invente chave).
      - Ignore textos, métodos, materiais, resultados anteriores e valores não numéricos.
    PROMPT
  end

  def numeric?(value)
    value.is_a?(Numeric) || value.to_s.strip.match?(/\A-?\d+(?:[.,]\d+)?\z/)
  end

  def numeric(value)
    return value.to_f if value.is_a?(Numeric)

    value.to_s.strip.tr(",", ".").to_f
  end

  def present_number(value)
    return value.to_f if value.is_a?(Numeric)
    return nil if value.to_s.strip.empty?

    numeric?(value) ? numeric(value) : nil
  end

  def parse_date(raw)
    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
