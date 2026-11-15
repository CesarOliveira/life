# One-off (DEPLOY_OPERACOES.md §2): cria a conta de demonstração do revisor da
# App Store. A senha vem da variável DEMO_PASSWORD do Railway, nunca do código.
# Idempotente: recria os dados da conta demo a cada execução.
email = "cesar+demo@integrattor.com.br"
password = ENV["DEMO_PASSWORD"].to_s

if password.length < 12
  puts "DEMO_REVIEW pulado: DEMO_PASSWORD ausente ou com menos de 12 caracteres"
else
  account = DemoAccount.new(email: email, password: password).call
  puts "DEMO_REVIEW ok: #{email} (conta #{account.id}, #{account.app_usages.count} usos, #{account.measurements.count} medidas)"
end
