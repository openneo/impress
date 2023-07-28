OpenneoImpressItems::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  config.cache_store = :mem_cache_store, namespace: "openneo-impress-rails"

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  # config.serve_static_assets = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!
  
  config.active_support.deprecation = :log

  # Compress JavaScripts and CSS
  config.assets.compress = true
   
  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false
   
  # Generate digests for assets URLs
  config.assets.digest = true
   
  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH
   
  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )
   
  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  config.react.variant = :production

  config.action_mailer.default_url_options = {host: "impress.openneo.net"}

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
     :address        => "mail.openneo.net",
     :port           => 587,
     :domain         => "openneo.net",
     :authentication => :login,
     :user_name      => "matchu@openneo.net",
     :password       => ENV.fetch("MATCHU_EMAIL_PASSWORD"),
     :enable_starttls_auto => false
  }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new
end

LocalImpressHost = 'newimpress.openneo.net'

RemoteImpressHost = 'impress.openneo.net'
