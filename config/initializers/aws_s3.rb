access_key_id = ENV.fetch('AWS_ACCESS_KEY_ID')
secret_access_key = ENV.fetch('AWS_SECRET_ACCESS_KEY')

def set(params, params_key, env_key)
  params[params_key] = ENV[env_key] if ENV.has_key?(env_key)
end

params = {}
set params, :server, 'AWS_SERVER_HOST'
set params, :port, 'AWS_SERVER_PORT'
set params, :protocol, 'AWS_SERVER_PROTOCOL'

IMPRESS_S3 = RightAws::S3.new access_key_id, secret_access_key, params
