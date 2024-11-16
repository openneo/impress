namespace :neopets do
	task :import => [
		"neopets:import:nc_mall",
		"neopets:import:rainbow_pool",
		"neopets:import:styling_studio",
	]
end
