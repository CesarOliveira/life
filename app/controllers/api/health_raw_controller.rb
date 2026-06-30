module Api
  # POST /api/health_raw?key=steps&period=today&client_version=v9
  #
  # Corpo = dados CRUAS de Saúde (um por linha), como o Atalho serializa. O atalho
  # NÃO calcula nada: só coleta e envia. Toda a agregação acontece AQUI, no Rails.
  #
  # Métricas numéricas (steps, resting_hr...): soma ou média das linhas.
  # Sono (sleep_start / sleep_end): cada linha é um horário (início/fim de uma
  # amostra). Calculamos dormiu = menor início, acordou = maior fim, e
  # horas dormidas = acordou - dormiu (janela de sono), gravando sleep_bedtime,
  # sleep_wake e sleep_minutes.
  #
  # A resposta inclui `raw_preview` (trecho do corpo) para diagnosticar o formato
  # vindo do iPhone, `value` (agregado) e `client_version` (confirma a versão).
  class HealthRawController < BaseController
    # Como agregar cada métrica numérica.
    AGG = {
      "steps" => :sum,
      "active_energy" => :sum,
      "sleep_minutes" => :sum,
      "resting_hr" => :avg
    }.freeze

    # Chaves de sono: cada linha é um horário; reduzimos por min/max.
    SLEEP_TIME = {
      "sleep_start" => { reduce: :min, store: "sleep_bedtime" },
      "sleep_end" => { reduce: :max, store: "sleep_wake" }
    }.freeze

    def create
      key = params[:key].to_s.strip.first(60)
      return render_error("invalid_key") if key.blank?

      date = parse_date(default_date_from(params) || Date.current.iso8601)
      return render_error("invalid_date") if date.nil? || !date_in_window?(date)

      raw = request.raw_post.to_s
      result = SLEEP_TIME.key?(key) ? handle_sleep_time(key, raw, date) : handle_numeric(key, raw, date)

      render json: {
        ok: true,
        key: key,
        **result,
        client_version: params[:client_version].to_s.first(40).presence,
        raw_preview: raw[0, 300]
      }
    end

    private

    def handle_numeric(key, raw, date)
      values = parse_values(raw)
      value = aggregate(key, values)
      { samples: values.size, value: value, upserted: store(key, value, date) }
    end

    # Sono: linhas são horários. Reduz por min/max, grava o horário (minutos
    # desde a meia-noite) e recalcula a duração quando dormiu e acordou existirem.
    def handle_sleep_time(key, raw, date)
      cfg = SLEEP_TIME.fetch(key)
      times = parse_times(raw)
      return { samples: 0, value: nil, upserted: 0 } if times.empty?

      chosen = cfg[:reduce] == :min ? times.min : times.max
      minutes = (chosen.hour * 60) + chosen.min
      upserted = store(cfg[:store], minutes, date)
      recompute_sleep_minutes(date)
      { samples: times.size, value: minutes, stored: cfg[:store], upserted: upserted }
    end

    # horas dormidas = acordou - dormiu (com wrap de meia-noite).
    def recompute_sleep_minutes(date)
      bedtime = current_account.measurements.find_by(key: "sleep_bedtime", measured_on: date)&.value
      wake = current_account.measurements.find_by(key: "sleep_wake", measured_on: date)&.value
      return if bedtime.nil? || wake.nil?

      store("sleep_minutes", (wake.to_i - bedtime.to_i) % 1440, date)
    end

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

    # Converte cada linha num horário. Aceita ISO 8601 e formatos comuns.
    def parse_times(raw)
      raw.split(/[\r\n]+/).filter_map do |line|
        next if line.strip.empty?

        Time.zone.parse(line.strip)
      rescue ArgumentError
        nil
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
