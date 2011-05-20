require 'yaml'

config = YAML.load_file Rails.root.join('config', 'aws_s3.yml')
access_key_id = config.delete 'access_key_id'
secret_access_key = config.delete 'secret_access_key'

IMPRESS_S3 = RightAws::S3.new access_key_id, secret_access_key, config

