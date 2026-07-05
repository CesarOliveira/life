# Criptografia de atributos (tokens de conectores). Em produção as chaves vêm
# do ENV (Railway); em dev/test usa chaves fixas (nada sensível fora de prod).
Rails.application.configure do
  fallback = Rails.env.production? ? nil : "life-#{Rails.env}-0000000000000000"
  config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", fallback)
  config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", fallback)
  config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", fallback)
end
