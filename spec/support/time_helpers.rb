# Disponibiliza travel_to/freeze_time nos specs (usados nos specs de janela de
# pregão). Sem isso, `travel_to` levanta NoMethodError.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end
