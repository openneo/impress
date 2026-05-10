namespace :neopets do
	task :import => [
		"neopets:import:neologin",
		"neopets:import:nc_mall",
		"neopets:import:rainbow_pool",
		"neopets:import:styling_studio",
	]

	namespace :import do
		# Loads the Neologin cookie. In normal use the latest NeologinCookie row
		# (managed via the admin panel at /admin/neologin) provides the value; the
		# NEOLOGIN_COOKIE env var is used as a fallback. If neither is configured
		# and we're running interactively, fall back to prompting.
		task :neologin => :environment do
			unless Neologin.cookie?
				if STDIN.tty?
					ENV["NEOLOGIN_COOKIE"] = STDIN.getpass("Neologin cookie: ")
				else
					raise "no Neologin cookie configured (set one via the admin " \
						"panel at /admin/neologin, or via NEOLOGIN_COOKIE env var)"
				end
			end
		end
	end
end
