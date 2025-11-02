require "addressable/template"

namespace "neopets:import" do
	desc "Import all basic image hashes from the Rainbow Pool, onto PetTypes"
	task :rainbow_pool => ["neopets:import:neologin", :environment] do
		begin
			puts "Importing from Rainbow Pool…"

			all_species = Species.order(:name).to_a
			all_pet_types = PetType.all.to_a
			all_pet_types_by_species_id_and_color_id = all_pet_types.
				to_h { |pt| [[pt.species_id, pt.color_id], pt] }
			all_colors_by_name = Color.all.to_h { |c| [c.human_name.downcase, c] }

			hashes_by_color_name_by_species_id = {}
			DTIRequests.load_many(max_at_once: 10) do |task|
				num_loaded = 0
				num_total = all_species.size
				print "0/#{num_total} species loaded"

				all_species.each do |species|
					task.async do
						begin
							hashes_by_color_name_by_species_id[species.id] =
								RainbowPool.load_hashes_for_species(species.id, Neologin.cookie)
						rescue => error
							puts "Failed to load #{species.name} page, skipping: #{error.message}"
							Sentry.capture_exception(error,
								tags: { task: "neopets:import:rainbow_pool" },
								contexts: { species: { name: species.name, id: species.id } })
						end
						num_loaded += 1
						print "\r#{num_loaded}/#{num_total} species loaded"
					end
				end
			end

			all_species.each do |species|
				hashes_by_color_name = hashes_by_color_name_by_species_id[species.id]
				next if hashes_by_color_name.nil?

				changed_pet_types = []

				hashes_by_color_name.each do |color_name, image_hash|
					color = all_colors_by_name[color_name.downcase]
					if color.nil?
						puts "Skipping unrecognized color name: #{color_name}"
						next
					end

					pet_type = all_pet_types_by_species_id_and_color_id[
						[species.id, color.id]]
					if pet_type.nil?
						puts "Skipping unrecognized pet type: " +
								"#{color_name} #{species.human_name}"
						next
					end

					if pet_type.basic_image_hash.nil?
						puts "Found new image hash: #{image_hash} (#{pet_type.human_name})"
						pet_type.basic_image_hash = image_hash
						changed_pet_types << pet_type
					elsif pet_type.basic_image_hash != image_hash
						puts "Updating image hash: #{image_hash} ({#{pet_type.human_name})"
						pet_type.basic_image_hash = image_hash
						changed_pet_types << pet_type
					else
						# No need to do anything with image hashes that match!
					end
				end

				PetType.transaction { changed_pet_types.each(&:save!) }
				puts "Saved #{changed_pet_types.size} image hashes for " +
						"#{species.human_name}"
			end
		rescue => e
			puts "Failed to import Rainbow Pool data: #{e.message}"
			puts e.backtrace.join("\n")
			Sentry.capture_exception(e, tags: { task: "neopets:import:rainbow_pool" })
			raise
		end
	end
end

module RainbowPool
	class << self
		SPECIES_PAGE_URL_TEMPLATE = Addressable::Template.new(
			"https://www.neopets.com/pool/all_pb.phtml{?f_species_id}"
		)
		def load_hashes_for_species(species_id, neologin)
			Sync do
				url = SPECIES_PAGE_URL_TEMPLATE.expand(f_species_id: species_id)
				DTIRequests.get(
					url,
					[["Cookie", "neologin=#{neologin}"]],
				) do |response|
					if response.status != 200
						raise "expected status 200 but got #{response.status} (#{url})"
					end

					parse_hashes_from_page response.read
				end
			end
		end

		private

		IMAGE_HASH_PATTERN = %r{
			set_pet_img\(
				'https?://pets\.neopets\.com/cp/(?<hash>[0-9a-z]+)/[0-9]+/[0-9]+\.png',
				\s*
				'(?<color_name>.+?)'
			\)
		}x
		def parse_hashes_from_page(html)
			html.scan(IMAGE_HASH_PATTERN).to_h do |(image_hash, color_name)|
				[color_name, image_hash]
			end
		end
	end
end
