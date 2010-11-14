Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies :openneo_auth_remember, :openneo_auth_token
  manager.failure_app = SessionsController.action(:failure)
end

require 'openneo-auth'
require 'yaml'

Openneo::Auth.configure do |config|
  YAML.load_file(Rails.root.join('config', 'openneo_auth.yml'))[Rails.env].each do |key, value|
    config.send("#{key}=", value)
  end
  
  config.remote_auth_user_finder do |user_data|
    User.find_or_create_from_remote_auth_data(user_data)
  end
  
  config.remember_user_finder do |id|
    User.find_by_id(id)
  end
end
