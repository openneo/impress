# For the openneo-camo.herokuapps.com server, which proxies assets through HTTPS.
# If you have no config, that's okay; we'll just serve the regular URL instead of the Camo URL.
CAMO_HOST = ENV['CAMO_HOST']
CAMO_KEY = ENV['CAMO_KEY']
