require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable static file serving from the `/public` folder (turn off if using NGINX/Apache for it).
  config.public_file_server.enabled = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  config.react.variant = :production

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.perform_caching = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: "impress.openneo.net"}

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
     :address        => "smtp.fastmail.com",
     :port           => 465,
     :tls            => true,
     :domain         => "openneo.net",
     :authentication => :login,
     :user_name      => "matchu@openneo.net",
     :password       => Rails.application.credentials.matchu_email_password,
     :enable_starttls_auto => false
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Allow pets to model new data. (If modeling is ever broken, disable this
  # here while we fix it!)
  config.modeling_enabled = true

  # Use the live copy of Impress 2020. (Can override this with the
  # IMPRESS_2020_ORIGIN environment variable!)
  config.impress_2020_origin = ENV.fetch("IMPRESS_2020_ORIGIN",
    "https://impress-2020.openneo.net")

  # Save the Neopets Media Archive in `/var/lib/neopets-media-archive`, a
  # long-term storage location.
  config.neopets_media_archive_root = "/var/lib/neopets-media-archive"

  # Save our public data exports in `public/public-data`. (This should be
  # symlinked to a shared folder persisted across all versions.)
  config.public_data_root = Rails.root / "public" / "public-data"

  # Use the live NeoPass production server.
  config.neopass_origin = "https://oidc.neopets.com"

  # Set the NeoPass redirect callback URL.
  config.neopass_redirect_uri =
    "https://impress.openneo.net/users/auth/neopass/callback"
end
