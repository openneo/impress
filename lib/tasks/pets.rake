namespace :pets do
	desc "Load a pet's viewer data"
	task :load, [:name] => [:environment] do |task, args|
		viewer_data = Neopets::CustomPets.fetch_viewer_data(args[:name])
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
