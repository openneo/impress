require_relative "boot"

require "rails"

# We disable some components we don't use, to: omit their routes, be confident
# that there's not e.g. surprise storage happening on the machine, and keep the
# app footprint smaller.
#
# Disabled:
# - active_storage/engine
# - active_job/railtie
# - action_cable/engine
# - action_mailbox/engine
# - action_text/engine
%w(
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  rails/test_unit/railtie
).each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenneoImpressItems
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

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

