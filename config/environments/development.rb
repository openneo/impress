OpenneoImpressItems::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  # NOTE: We have caching on in development, to make it easier to test it!
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = true

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = {host: "impress.dev.openneo.net"}
  config.action_mailer.delivery_method = :letter_opener

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  config.react.variant = :development

  # Fix file reloading in a Vagrant environment.
  # The `ActiveSupport::EventedFileUpdateChecker` is faster, but doesn't work
  # correctly for Vagrant's networked folders!
  # https://stackoverflow.com/a/36616931
  #
  # TODO: In the future, if we don't expect the use of Vagrant or similar tech
  # anymore, we could remove this for a minor dev perf improvement. We're on
  # Vagrant now because it's hard to get older Ruby running on many modern
  # systems, but later on that could change!
  #
  # NOTE: But I also see that this might be the default anyway in current
  # Rails? idk when that changed... so maybe just delete this later?
  config.file_watcher = ActiveSupport::FileUpdateChecker
end

LocalImpressHost = 'betanewimpress.openneo.net'

RemoteImpressHost = 'beta.impress.openneo.net'

