OpenneoImpressItems::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false
  
  config.active_support.deprecation = :log
  
  config.threadsafe!
end

RemoteImpressHost = 'beta.impress.openneo.net'

USE_FIBER_POOL = true

OPENNEO_AUTH_CONFIG = {
  :app => 'beta.items.impress',
  :auth_server => 'beta.id.openneo.net',
  :secret => 'zaheh2draswAb8eneca$3an?2ADAsTuwra8h7BujUBr_w--p2-a@e?u!taQux3tr'
}