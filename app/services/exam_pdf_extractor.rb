require "net/http"
require "base64"
require "json"

# Extrai resultados de um PDF de exame laboratorial usando a API da Anthropic
# (Claude, com leitura de PDF) e devolve linhas prontas para virar `Measurement`
# (categoria "exam"). Sem chave configurada, degrada com erro "not_configured".
#
# Requer ENV["ANTHROPIC_API_KEY"]. Modelo via ENV["LIFE_EXTRACTION_MODEL"]
# (padrão: claude-sonnet-4-6). O PDF é processado em memória — não é persistido.
class ExamPdfExtractor
  Result = Struct.new(:rows, :measured_on, :error, keyword_init: true) do
    def ok?
      error.nil?
    end
  end

  API_URL = "https://api.anthropic.com/v1/messages"
  DEFAULT_MODEL = "claude-sonnet-4-6".freeze
  MAX_BYTES = 15 * 1024 * 1024
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

    json = request_extraction(Base64.strict_encode64(@data))
    build_result(json)
  rescue Net::OpenTimeout, Net::ReadTimeout
    Result.new(error: "timeout")
  rescue StandardError => e
    Rails.logger.error("ExamPdfExtractor: #{e.class}: #{e.message}")
    Result.new(error: "extraction_failed")
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

  def request_extraction(base64_pdf)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"
    request["content-type"] = "application/json"
    request.body = payload(base64_pdf).to_json

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.body}" unless response.code.to_i == 200

    extract_json(JSON.parse(response.body))
  end

  def payload(base64_pdf)
    {
      model: ENV["LIFE_EXTRACTION_MODEL"].presence || DEFAULT_MODEL,
      max_tokens: 2000,
      messages: [
        {
          role: "user",
          content: [
            { type: "document", source: { type: "base64", media_type: "application/pdf", data: base64_pdf } },
            { type: "text", text: prompt }
          ]
        }
      ]
    }
  end

  # Pega o texto da resposta do Claude e faz parse do JSON (tolera cercas ```json).
  def extract_json(response_body)
    text = Array(response_body["content"]).filter_map { |b| b["text"] }.join("\n")
    text = text.gsub(/```json\s*/i, "").gsub(/```/, "").strip
    JSON.parse(text)
  end

  def prompt
    catalog = Measurement.catalog_keys("exam").join(", ")
    <<~PROMPT
      Você recebe o PDF de um exame laboratorial. Extraia TODOS os resultados numéricos.
      Responda APENAS com JSON válido (sem markdown, sem comentários), neste formato:
      {"measured_on":"YYYY-MM-DD","results":[{"key":"glucose","value":92,"unit":"mg/dL","ref_low":70,"ref_high":99}]}

      Regras:
      - "measured_on": data da coleta (ISO). Se não houver, omita.
      - Use estas chaves canônicas quando o analito corresponder: #{catalog}.
        Ex.: "Glicose"->glucose, "Colesterol total"->cholesterol_total, "HDL"->hdl,
        "LDL"->ldl, "Triglicerídeos"->triglycerides, "TSH"->tsh, "Vitamina D"->vitamin_d.
      - Para analitos sem chave canônica, gere uma chave em snake_case em inglês.
      - "value" deve ser número (ponto decimal). Inclua "unit" e a faixa de referência
        (ref_low/ref_high) quando o laudo informar; senão omita esses campos.
      - Ignore textos descritivos, métodos e valores não numéricos.
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
