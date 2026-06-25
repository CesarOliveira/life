require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Life
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_support.message_serializer = :message_pack
    config.action_dispatch.cookies_serializer = :message_pack
    config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
    routes.default_url_options[:host] = ENV.fetch("URL_HOST") { "localhost:8000" }

    config.time_zone = "America/Sao_Paulo"
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [:"pt-BR", :en]
    config.i18n.fallbacks = true

    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_URL") { "redis://redis:6379/1" },
      namespace: "cache",
      serializer: :message_pack
    }

    config.active_job.queue_adapter = :sidekiq

    # Railway: mount Action Cable in main app. Docker dev: separate cable process.
    if ENV["RAILWAY_ENVIRONMENT"].present?
      config.action_cable.mount_path = "/cable"
    else
      config.action_cable.mount_path = nil
      config.action_cable.url = ENV.fetch("ACTION_CABLE_FRONTEND_URL") { "ws://localhost:28080" }
    end

    origins = ENV.fetch("ACTION_CABLE_ALLOWED_REQUEST_ORIGINS") { "http:\/\/localhost*" }.split(",")
    origins.map! { |url| /#{url}/ }
    config.action_cable.allowed_request_origins = origins
  end
end
