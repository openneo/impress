require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = {host: "localhost", port: 3000}
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_caching = false

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  config.react.variant = :development

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Don't use the assets precompiled for production; recompile live instead.
  # HACK: We do this by just telling it that dev assets belong in a special
  # folder, so if you run precompile in development it'll look there instead,
  # as recommended by the Rails guide. But I don't actually use that irl!
  # https://guides.rubyonrails.org/v7.0.7/asset_pipeline.html#local-precompilation
  config.assets.prefix = "/dev-assets"

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

  # Allow connections on Vagrant's private network.
  config.web_console.permissions = '10.0.2.2'
end
