# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

use Rack::FiberPool if defined?(USE_FIBER_POOL) && USE_FIBER_POOL
run OpenneoImpressItems::Application
