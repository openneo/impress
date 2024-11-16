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
		task :neologin do
			unless Neologin.cookie?
				Neologin.cookie = STDIN.getpass("Neologin cookie: ")
			end
		end
	end
end
