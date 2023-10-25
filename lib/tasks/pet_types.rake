namespace :pet_types do
  namespace :pranks do
    desc 'Create a prank pet type with one state and one asset'
    task :create, [:color_id, :species_id, :body_id, :asset_remote_id, :asset_url, :female, :mood_id, :unconverted, :zones_restrict] => :environment do |t, args|
      args.with_defaults(female: false, mood_id: 1, unconverted: false,
        zone_id: 15, # body zone; a pretty good compromise for most items
        zones_restrict: '0000000000000000000000000000000000000000000000000000')
      PetType.transaction do
        swf_asset = SwfAsset.new
        swf_asset.type = 'biology'
        swf_asset.remote_id = args[:asset_remote_id]
        swf_asset.url = args[:asset_url]
        swf_asset.zone_id = args[:zone_id]
        swf_asset.zones_restrict = args[:zones_restrict]
        swf_asset.body_id = 0 # biology assets use 0, not pet type's body id
        swf_asset.has_image = false
        swf_asset.image_requested = false
        swf_asset.save! # get it an ID
        puts "Asset #{swf_asset.inspect} created"

        pet_type = PetType.new
        pet_type.color_id = args[:color_id]
        pet_type.species_id = args[:species_id]
        pet_type.body_id = args[:body_id]
        # This isn't really a valid image hash, but we can teach PetType to
        # use this override when reporting its image URLs.
        pet_type.image_hash = "a:#{swf_asset.remote_id}"
        pet_type.save!
        puts "Pet type #{pet_type.inspect} created"

        pet_state = pet_type.pet_states.build
        pet_state.swf_asset_ids = "#{swf_asset.id}"
        pet_state.female = args[:female]
        pet_state.mood_id = args[:mood_id]
        pet_state.unconverted = args[:unconverted]
        pet_state.labeled = true
        pet_state.glitched = false
        pet_state.save!
        puts "Pet state #{pet_state.inspect} created"

        parent_swf_asset_relationship = ParentSwfAssetRelationship.new
        parent_swf_asset_relationship.parent = pet_state
        parent_swf_asset_relationship.swf_asset = swf_asset
        parent_swf_asset_relationship.save!
        puts "Relationship #{parent_swf_asset_relationship.inspect} created"
      end
    end
  end

  desc "Download the Rainbow Pool data for the given locale"
  task :download_basic_image_hashes => :environment do
    Species.find_each do |species|
      pool_url = "https://www.neopets.com/pool/all_pb.phtml"
      pool_options = {
        :cookies => {:neologin => URI.encode(ENV['NEOLOGIN'])},
        :params => {:lang => 'en', :f_species_id => species.id}
      }
      pool_response = RestClient.get(pool_url, pool_options)
      pool_doc = Nokogiri::HTML(pool_response)

      counts = {saved: 0, skipped: 0}
      PetType.transaction do
        pool_doc.css('a[onclick^="set_pet_img("]').each do |link|
          color = Color.find_by_name link.text
          pet_type = PetType.find_by_species_id_and_color_id species, color
          if pet_type
            image_hash = PetType.get_hash_from_cp_path(link['onclick'][36..55])
            pet_type.basic_image_hash = image_hash
            pet_type.save!
            counts[:saved] += 1
            puts "* #{pet_type.human_name}: #{pet_type.basic_image_hash}"
          else
            dummy_pet_type = PetType.new color: color, species: species
            counts[:skipped] += 1
            puts "  #{dummy_pet_type.human_name}: skip: not yet modeled"
          end
        end
      end
      puts "- #{species.human_name}: saved #{counts[:saved]}, skipped #{counts[:skipped]}"
    end
  end
end