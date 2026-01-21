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

			# Look up the PetType to use for the preview
			pet_type = PetType.matching_name(color_name, species_name).first!

			# Convert it to an image hash for direct lookup
			new_image_hash = Neopets::NCMall.fetch_pet_data_sci(pet_type.image_hash, item_ids)
			pet_name = '@' + new_image_hash
			$stderr.puts "Loading pet #{pet_name}"

			# Load the image hash as if it were a pet
			viewer_data = Neopets::CustomPets.fetch_viewer_data(pet_name)
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
