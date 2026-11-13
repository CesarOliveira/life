require "open3"

module Ops
  # GET /ops/backup — devolve um dump completo do banco (pg_dump, formato custom,
  # já comprimido), para ser baixado e guardado FORA do Railway.
  #
  # Protegido por um segredo próprio, ENV["BACKUP_TOKEN"], no cabeçalho
  # Authorization: Bearer. Sem a variável definida a rota não existe (404).
  # O dump contém todos os dados de todas as contas: trate o token como a senha
  # do banco.
  class BackupsController < ActionController::API
    RATE_LIMIT = 6 # por hora

    def show
      secret = ENV["BACKUP_TOKEN"].to_s
      return head(:not_found) if secret.length < 32

      given = request.headers["Authorization"].to_s[/\ABearer\s+(.+)\z/i, 1].to_s
      return head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(given, secret)
      return head(:too_many_requests) if throttled?

      dump, error, status = Open3.capture3(pg_env, "pg_dump", "--format=custom", "--no-owner", "--no-privileges", binmode: true)
      unless status.success? && dump.start_with?("PGDMP")
        Rails.logger.error("Backup: pg_dump falhou (#{status.exitstatus}): #{error.to_s.first(300)}")
        return head(:internal_server_error)
      end

      response.set_header("Cache-Control", "no-store")
      send_data dump, filename: "life-#{Time.current.strftime('%Y-%m-%d-%H%M')}.dump", type: "application/octet-stream"
    end

    private

    # Credenciais vão por variáveis de ambiente do processo filho, não na linha
    # de comando (que aparece na lista de processos).
    def pg_env
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      { "PGHOST" => config[:host].to_s, "PGPORT" => (config[:port] || 5432).to_s, "PGUSER" => config[:username].to_s,
        "PGPASSWORD" => config[:password].to_s, "PGDATABASE" => config[:database].to_s,
        "PGSSLMODE" => (config[:sslmode] || "prefer").to_s }
    end

    def throttled?
      return false if Rails.env.test?

      Rails.cache.increment("backup_rl", 1, expires_in: 1.hour).to_i > RATE_LIMIT
    end
  end
end
