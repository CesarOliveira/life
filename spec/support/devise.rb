# Disponibiliza os helpers de autenticação do Devise (sign_in/sign_out) nos
# specs, conforme o tipo. Sem isso, `sign_in user` levanta NoMethodError.
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::ControllerHelpers,  type: :controller
end
