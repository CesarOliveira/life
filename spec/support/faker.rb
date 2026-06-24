# O Faker cai para I18n.locale quando não tem locale próprio configurado. Como o
# app roda em pt-BR e o dataset pt-BR do Faker não cobre todas as chaves (ex.
# name.full_name), fixamos :en nos testes para gerar dados estáveis. Afeta só o
# Faker; o I18n da aplicação continua pt-BR.
Faker::Config.locale = :en
