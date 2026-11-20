Sentry.init do |config|
  config.dsn = 'https://2d3c5b739af149a0b3beb86a4d498e1f@health.openneo.net/1'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Only report from production. Otherwise, specs that exercise error paths
  # (in CI, or on a dev machine) file real-looking issues in GlitchTip.
  config.enabled_environments = %w[production]

  # Falcon serves concurrent requests as fibers on a shared thread, so Sentry's
  # default per-thread hub let one request's scope (transaction name, request
  # data, breadcrumbs) leak onto another request's errors. That mislabeled
  # events, and split one bug across several GlitchTip issues.
  config.hub_isolation_level = :fiber
end
