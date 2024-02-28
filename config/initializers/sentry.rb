Sentry.init do |config|
  config.dsn = 'https://2d3c5b739af149a0b3beb86a4d498e1f@health.openneo.net/1'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.05
end
