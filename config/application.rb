require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenneoImpressItems
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.fallbacks = true

    Mime::Type.register "image/gif", :gif

    ActionController::Base.config.relative_url_root = ''

    config.assets.enabled = true
    config.assets.version = '1.0'
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
    config.assets.precompile << '*.js'
    config.assets.initialize_on_precompile = false

    config.middleware.insert_after ActionDispatch::Flash, Rack::Attack
  end
end

