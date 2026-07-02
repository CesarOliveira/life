source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.5"

gem "rails", "~> 8.1"
gem "msgpack", ">= 1.7.0"
gem "propshaft", "~> 1.1"
gem "pg", "~> 1.1"
gem "puma", "~> 7.1"
gem "jsbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"
gem "redis", "~> 5.2"
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
gem "connection_pool", "~> 2"
gem "sidekiq", "~> 8.0"
gem "sidekiq-cron", "~> 2.0"
gem "devise"
gem "rails-i18n"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
gem "pagy", "~> 9.0"
gem "activeadmin"
gem "pdf-reader", "~> 2.12" # extrai texto do PDF localmente (import de exames barato)

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  gem "hotwire-spark", "~> 0.1"
  gem "annotaterb"
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "database_cleaner-active_record"
  gem "capybara"
  gem "selenium-webdriver"
end

gem "devise-i18n", "~> 1.16"
