namespace "neopets:import" do
	desc "Import colors and pet type image hashes from the Rainbow Pool, " +
		"modeling new pet types"
	task :rainbow_pool => ["neopets:import:neologin", :environment] do
		# NOTE: We don't raise out of this task, even if something goes wrong,
		# because that would stop `neopets:import` from running the tasks after
		# this one. Instead, we report problems to Sentry, and carry on.
		sentry_tags = PetType::RainbowPoolImport::SENTRY_TAGS
		safe_message = PetType::RainbowPoolImport.method(:safe_message)
		puts "Importing from Rainbow Pool…"

		# Load the list of all species and colors.
		begin
			all_pets = Neopets::RainbowPool.load_all_pets
			puts "#{all_pets[:species].size} species and " +
				"#{all_pets[:colors].size} colors listed"
		rescue => error
			puts "⚠️  Failed to load species and colors list, skipping: " +
				safe_message.(error)
			Sentry.capture_exception(error, tags: sentry_tags)
			all_pets = {species: [], colors: []}
		end

		# Load paint brushes, which we use for colors' paint brush info. If this
		# fails, we can carry on without them.
		begin
			brushes = Neopets::RainbowPool.load_brushes
			puts "#{brushes.size} paint brushes loaded"
		rescue => error
			puts "⚠️  Failed to load paint brushes, skipping: " +
				safe_message.(error)
			Sentry.capture_exception(error, tags: sentry_tags)
			brushes = []
		end

		# Load the colors for each species, 10 at a time.
		all_species = Species.order(:name).to_a
		colors_by_species_id = {}
		errors_by_species = {}
		DTIRequests.load_many(max_at_once: 10) do |task|
			num_loaded = 0
			num_total = all_species.size
			print "0/#{num_total} species loaded"

			all_species.each do |species|
				task.async do
					begin
						colors_by_species_id[species.id] =
							Neopets::RainbowPool.load_colors_for_species(species.id)
					rescue => error
						errors_by_species[species] = error
						puts "\n⚠️  Failed to load #{species.human_name}, skipping: " +
							safe_message.(error)
					end
					num_loaded += 1
					print "\r#{num_loaded}/#{num_total} species loaded"
				end
			end
		end
		puts ""

		# Report species failures to Sentry as one event, rather than one per
		# species, so an outage doesn't flood it.
		if errors_by_species.any?
			species_names = errors_by_species.keys.map(&:human_name).sort
			puts "⚠️  Failed to load #{errors_by_species.size} of " +
				"#{all_species.size} species: #{species_names.join(", ")}"
			Sentry.capture_exception(errors_by_species.values.first,
				tags: sentry_tags,
				contexts: {
					rainbow_pool: {
						failed_species_count: errors_by_species.size,
						total_species_count: all_species.size,
						errors: errors_by_species.to_h { |species, error|
							[species.human_name, safe_message.(error)]
						},
					},
				})
		end

		begin
			result = PetType::RainbowPoolImport.new(colors_by_species_id,
				species: all_pets[:species], colors: all_pets[:colors], brushes:).run!
			puts "Done! #{result.new_colors.size} new colors, " +
				"#{result.updated_colors.size} colors updated, " +
				"#{result.modeled_pet_types.size} new pet types, " +
				"#{result.updated_pet_types.size} image hashes saved"
		rescue => error
			puts "⚠️  Failed to import Rainbow Pool data: #{safe_message.(error)}"
			puts error.backtrace.join("\n")
			Sentry.capture_exception(error, tags: sentry_tags)
		end
	end
end
