namespace :pets do
	desc "Load a pet's viewer data (by name or by color/species/items)"
	task :load, [:first] => [:environment] do |task, args|
		# Collect all arguments (first + extras)
		all_args = [args[:first]] + args.extras

		# If only one argument, treat it as a pet name
		if all_args.length == 1
			viewer_data = Neopets::CustomPets.fetch_viewer_data(all_args[0])
		else
			# Multiple arguments: color, species, and optional item IDs
			color_name = all_args[0]
			species_name = all_args[1]
			item_ids = all_args[2..]

			# Look up the PetType to get its image hash
			pet_type = PetType.matching_name(color_name, species_name).first!
			pet_sci = pet_type.image_hash

			# Fetch the new image hash for this pet+items combination
			response = Neopets::NCMall.fetch_pet_data(pet_sci, item_ids)
			new_sci = response[:newsci]

			# Output the hash to stderr for debugging
			$stderr.puts "Generated image hash: #{new_sci}"

			# Load the full viewer data using the new image hash
			viewer_data = Neopets::CustomPets.fetch_viewer_data("@#{new_sci}")
		end

		puts JSON.pretty_generate(viewer_data)
	end

	desc "Find pets that were, last we saw, of the given color and species"
	task :find, [:color_name, :species_name] => [:environment] do |task, args|
		begin
			pt = PetType.matching_name(args.color_name, args.species_name).first!
		rescue ActiveRecord::RecordNotFound
			abort "Could not find pet type for " +
			      "#{args.color_name} #{args.species_name}"
		end

		limit = ENV.fetch("LIMIT", 10)

		pt.pets.limit(limit).order(id: :desc).pluck(:name).each do |pet_name|
			puts "- #{pet_name} (https://www.neopets.com/petlookup.phtml?pet=#{pet_name})"
		end
	end
end
