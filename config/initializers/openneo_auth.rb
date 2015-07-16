require 'openneo-auth'

Openneo::Auth.configure do |config|
  config.app = ENV.fetch('OPENNEO_AUTH_APP')
  config.auth_server = ENV.fetch('OPENNEO_AUTH_SERVER')
  config.secret = ENV.fetch('OPENNEO_AUTH_SECRET')

  config.remote_auth_user_finder do |user_data|
    User.find_or_create_from_remote_auth_data(user_data)
  end

  config.remember_user_finder do |id|
    User.find_by_id(id)
  end
end
