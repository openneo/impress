if Rails.env.production?
  Rails.configuration.neopia_host = 'neopia.openneo.net'
else
  Rails.configuration.neopia_host = 'localhost:3200'
end