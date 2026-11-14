namespace :demo do
  desc "Cria ou recria a conta de demonstração (App Store/revisão). EMAIL=... PASSWORD=... [NAME=...]"
  task seed: :environment do
    email = ENV.fetch("EMAIL")
    account = DemoAccount.new(email: email, password: ENV.fetch("PASSWORD"), name: ENV.fetch("NAME", "Ana Souza")).call
    puts "Conta demo pronta: #{email} (conta #{account.id}, token #{account.api_token.first(4)}…)"
  end
end
