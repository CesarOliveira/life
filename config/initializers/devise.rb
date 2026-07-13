Devise.setup do |config|
  config.mailer_sender = "noreply@example.com"
  require "devise/orm/active_record"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = false
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other

  # OmniAuth — Login com o Google (OAuth2). Credenciais via ENV: GOOGLE_CLIENT_ID
  # e GOOGLE_CLIENT_SECRET (.env em dev, Variables do Railway em prod). Sem as
  # credenciais o botão não funciona, mas a aplicação sobe normalmente.
  # provider_ignores_state: o login do app nativo roda num navegador embutido
  # (ASWebAuthenticationSession) onde a sessão NÃO sobrevive à volta do Google
  # (SameSite) — logo o "omniauth.state" guardado na sessão vem nil no callback
  # e o check de state estoura. Desligamos o check de state; a iniciação do
  # login continua protegida por omniauth-rails_csrf_protection (fase de request).
  config.omniauth :google_oauth2,
                  ENV["GOOGLE_CLIENT_ID"],
                  ENV["GOOGLE_CLIENT_SECRET"],
                  scope: "email,profile",
                  prompt: "select_account",
                  access_type: "online",
                  provider_ignores_state: true
end
