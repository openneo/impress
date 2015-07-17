# By default, we'll have CarrierWave use S3 only on production. (Since each
# asset image has only One True Image no matter the environment, we'll override
# this to use S3 on all environments for those images only.)

CarrierWave.configure do |config|
  if Rails.env.production?
    config.storage = :fog
    config.fog_credentials = {
      :provider               => 'AWS',
      :aws_access_key_id      => ENV.fetch('AWS_ACCESS_KEY_ID'),
      :aws_secret_access_key  => ENV.fetch('AWS_SECRET_ACCESS_KEY')
    }
  else
    config.storage = :file
  end
end
