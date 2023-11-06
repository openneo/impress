Sentry.init do |config|
  config.dsn = 'https://cb4b3f56c1ec50ba0667b189617446bb@o506079.ingest.sentry.io/4506180803559424'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.2
end
