# By default, we'll have CarrierWave use S3 only on production. (Since each
# asset image has only One True Image no matter the environment, we'll override
# this to use S3 on all environments for those images only.)

CarrierWave.configure do |config|
  if Rails.env.production?
    s3_config = YAML.load_file Rails.root.join('config', 'aws_s3.yml')
    access_key_id = s3_config['access_key_id']
    secret_access_key = s3_config['secret_access_key']
    
    config.storage = :fog
    config.fog_credentials = {
      :provider               => 'AWS',
      :aws_access_key_id      => access_key_id,
      :aws_secret_access_key  => secret_access_key
    }
  else
    config.storage = :file
  end
end
