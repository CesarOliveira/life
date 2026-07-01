# One-off: remove registros de tempo de uso com bundle_id artefato "Nome ()"
# (parser antigo do /api/usage_raw). Idempotente e seguro. Rodar via
# `rails runner db/cleanup_usage_parens.rb` no boot e depois reverter (ver
# DEPLOY_OPERACOES.md §2).
begin
  n = AppUsage.where("bundle_id LIKE ?", "%()").delete_all
  puts "[cleanup_usage_parens] deleted #{n} rows"
rescue StandardError => e
  warn "[cleanup_usage_parens] #{e.class}: #{e.message}"
end
