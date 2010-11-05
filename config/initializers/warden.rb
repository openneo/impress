Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies :openneo_auth_token
  manager.failure_app = SessionsController.action(:failure)
end

require 'openneo-auth'

Openneo::Auth.configure do |config|
  OPENNEO_AUTH_CONFIG.each do |key, value|
    config.send("#{key}=", value)
  end
  
  config.user_finder do |user_data|
    User.find_or_create_from_remote_auth_data(user_data)
  end
end
