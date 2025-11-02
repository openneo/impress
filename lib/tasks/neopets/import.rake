module Neologin
	def self.cookie
		raise "must run neopets:import:neologin first" if @cookie.nil?
		@cookie
	end

	def self.cookie?
		@cookie.present?
	end

	def self.cookie=(new_cookie)
		@cookie = new_cookie
	end
end

namespace :neopets do
	task :import => [
		"neopets:import:neologin",
		"neopets:import:nc_mall",
		"neopets:import:rainbow_pool",
		"neopets:import:styling_studio",
	]

	namespace :import do
		# Gets the neologin cookie, either from ENV['NEOLOGIN_COOKIE'] or by prompting.
		# The neologin cookie is required for authenticated Neopets requests (Rainbow Pool,
		# Styling Studio). It's generally long-lived (~1 year), so it can be stored in the
		# environment and rotated manually when it expires.
		#
		# To extract the cookie:
		# 1. Log into Neopets.com in your browser
		# 2. Open browser DevTools > Application/Storage > Cookies
		# 3. Find the "neologin" cookie value
		# 4. Set NEOLOGIN_COOKIE environment variable to that value
		# 5. Update production.env and redeploy when the cookie expires
		task :neologin do
			unless Neologin.cookie?
				# Try environment variable first (for automated cron jobs)
				if ENV['NEOLOGIN_COOKIE'].present?
					Neologin.cookie = ENV['NEOLOGIN_COOKIE']
				else
					# Fall back to interactive prompt (for local development)
					Neologin.cookie = STDIN.getpass("Neologin cookie: ")
				end
			end
		end
	end
end
