require "spec_helper"
# Força o ambiente de teste: o container de dev seta RAILS_ENV=development, e com
# `||=` os specs rodariam no banco de dev e sem o group :test (ex.: shoulda).
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("RAILS_ENV is production") if Rails.env.production?
require "rspec/rails"

# Mantém o schema do banco de teste sincronizado com db/schema.rb ao rodar os
# specs (assim `./run test` / `bundle exec rspec` não precisam de db:test:prepare).
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
