require_relative "boot"

require "rails"

# We disable some components we don't use, to: omit their routes, be confident
# that there's not e.g. surprise storage happening on the machine, and keep the
# app footprint smaller.

# require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenneoImpressItems
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Pacific Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.available_locales = [:en, :es, :pt, :"en-MEEP"]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = true

    Mime::Type.register "image/gif", :gif

    ActionController::Base.config.relative_url_root = ''

    config.assets.enabled = true
    config.assets.version = '1.0'
    config.assets.precompile << '*.js'
    config.assets.initialize_on_precompile = false
    config.assets.css_compressor = nil # Sass's compressor can't handle all modern CSS…

    config.middleware.insert_after ActionDispatch::Flash, Rack::Attack

    # On the Falcon server, requests run on fibers. Isolate Rails internal
    # state to the per-fiber level, to avoid conflicts that crash stuff!
    config.active_support.isolation_level = :fiber

    # It seems like some Neopets servers reject any user agent containing
    # symbols? So I can't provide anything helpful like a URL, email address,
    # version number, etc. So let's only send this to Neopets systems, where it
    # should hopefully be clear who we are from context!
    #
    # NOTE: To be able to access Neopets.com, the User-Agent string must contain
    #       a slash character.
    config.user_agent_for_neopets = "Dress to Impress (https://impress.openneo.net)"

    # Use the usual Neopets.com, unless we have an override. (At times, we've
    # used this in collaboration with TNT to address the server directly,
    # instead of through the CDN.)
    config.neopets_origin =
      ENV.fetch('NEOPETS_URL_ORIGIN', 'https://www.neopets.com')
  end
end

