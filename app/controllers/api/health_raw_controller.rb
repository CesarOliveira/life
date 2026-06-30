module Api
  # POST /api/health_raw?key=steps&period=today&client_version=v5
  #
  # Corpo = amostras CRUAS de Saúde (texto, como o Atalho serializa a lista de
  # amostras). O atalho NÃO calcula nada: só coleta as amostras e envia. Toda a
  # agregação (somar passos, média de FC, etc.) acontece AQUI, no Rails.
  #
  # A resposta inclui `raw_preview` (trecho do corpo recebido) para diagnosticar
  # o formato vindo do iPhone, `value` (agregado) e `client_version` (confirma
  # qual versão do atalho rodou — evita arquivo cacheado).
  class HealthRawController < BaseController
    # Como agregar cada métrica a partir das amostras cruas.
    AGG = {
      "steps" => :sum,
      "active_energy" => :sum,
      "sleep_minutes" => :sum,
      "resting_hr" => :avg
    }.freeze

    def create
      key = params[:key].to_s.strip.first(60)
      return render_error("invalid_key") if key.blank?

      date = parse_date(default_date_from(params) || Date.current.iso8601)
      return render_error("invalid_date") if date.nil? || !date_in_window?(date)

      raw = request.raw_post.to_s
      values = parse_values(raw)
      value = aggregate(key, values)

      upserted = store(key, value, date)

      render json: {
        ok: true,
        key: key,
        samples: values.size,
        value: value,
        upserted: upserted,
        client_version: params[:client_version].to_s.first(40).presence,
        raw_preview: raw[0, 300]
      }
    end

    private

    def store(key, value, date)
      return 0 if value.nil?

      meta = Measurement.meta(key)
      row = {
        account_id: current_account.id,
        key: key,
        value: value,
        unit: meta[:unit],
        measured_on: date,
        category: (meta[:category] || "health").to_s,
        ref_low: meta[:ref_low],
        ref_high: meta[:ref_high],
        source: "api"
      }
      Measurement.upsert_all([row], unique_by: :idx_measurements_unique, record_timestamps: true)
      HabitRuleEvaluator.new(current_account).evaluate([date])
      1
    end

    # Extrai um número por linha (ignora unidades/texto). Entende pt-BR.
    def parse_values(raw)
      raw.split(/[\r\n]+/).filter_map do |line|
        token = line[/-?\d[\d.,]*/]
        numeric(token) if token
      end
    end

    def aggregate(key, values)
      return nil if values.empty?

      case AGG[key]
      when :avg then (values.sum / values.size).round(2)
      else values.sum.round(2)
      end
    end

    # "8.021" -> 8021, "1.234,5" -> 1234.5, "7,5" -> 7.5, "437" -> 437.
    def numeric(value)
      str = value.to_s.strip.sub(/[.,]+\z/, "")
      str =
        if str.include?(",")
          str.delete(".").tr(",", ".")
        elsif str.match?(/\A-?\d{1,3}(\.\d{3})+\z/)
          str.delete(".")
        else
          str
        end
      str.to_f
    end
  end
end
