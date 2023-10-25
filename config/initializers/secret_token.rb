# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
# You can use `rake secret` to generate a secure secret key.

# Make sure your secret_key_base is kept private
# if you're sharing your code publicly.
if Rails.env.development?
	# In development, we use a hardcoded secret key, because it doesn't actually
	# need to be secret!
	OpenneoImpressItems::Application.config.secret_key_base = "7584841652f89044a8b5a428efa6dfac2461449eb24741a33668cd642130d79f93b0347766ebf4a4d7d5033a263c36431594ad56b5735a7325c8cdda991219c2"
else
	# In general, we use the SECRET_TOKEN provided as an environment variable!
	OpenneoImpressItems::Application.config.secret_key_base = ENV.fetch('SECRET_TOKEN')
end
