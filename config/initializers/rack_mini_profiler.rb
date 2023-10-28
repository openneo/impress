Rails.configuration.to_prepare do
	Rack::MiniProfiler.config.enable_advanced_debugging_tools = true
end
