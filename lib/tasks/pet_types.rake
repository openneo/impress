namespace :pet_types do
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