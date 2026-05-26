namespace "neopets:import" do
	desc "Import alt style info from the NC Styling Studio"
	task :styling_studio => ["neopets:import:neologin", :environment] do
		begin
			puts "Importing from Styling Studio…"

			all_species = Species.order(:name).to_a

			# Load 10 species pages from the NC Mall at a time.
			styles_by_species_id = {}
			DTIRequests.load_many(max_at_once: 10) do |task|
				num_loaded = 0
				num_total = all_species.size
				print "0/#{num_total} species loaded"

				all_species.each do |species|
					task.async {
						begin
							styles_by_species_id[species.id] = Neologin.with_tracking do
								Neopets::NCMall.load_styles(species_id: species.id)
							end
						rescue => error
							puts "\n⚠️  Error loading for #{species.human_name}, skipping: #{error.message}"
							Sentry.capture_exception(error,
								tags: { task: "neopets:import:styling_studio" },
								contexts: { species: { name: species.human_name, id: species.id } })
						end
						num_loaded += 1
						print "\r#{num_loaded}/#{num_total} species loaded"
					}
				end
			end
			print "\n"

			# Load exclusive styles from tab 3 (not species-specific).
			print "Loading exclusives…"
			begin
				exclusives = Neologin.with_tracking do
					Neopets::NCMall.load_exclusives
				end
			rescue => error
				puts "\n⚠️  Error loading exclusives, skipping: #{error.message}"
				Sentry.capture_exception(error,
					tags: { task: "neopets:import:styling_studio" })
				exclusives = nil
			end
			puts " #{exclusives&.size || 0} loaded"

			all_styles = styles_by_species_id.values.flatten(1)
			all_styles += exclusives unless exclusives.nil?
			style_ids = all_styles.map { |s| s[:oii] }
			style_records_by_id =
				AltStyle.where(id: style_ids).to_h { |as| [as.id, as] }

			# Build a list of groups to process: one per species, plus exclusives.
			groups = all_species.map { |sp|
				{label: sp.human_name, styles: styles_by_species_id[sp.id]}
			}
			groups << {label: "Exclusives", styles: exclusives}

			groups.each do |group|
				styles = group[:styles]
				next if styles.nil?

				counts = {changed: 0, unchanged: 0, skipped: 0}
				styles.each do |style|
					record = style_records_by_id[style[:oii]]
					label = "#{style[:name]} (#{style[:oii]})"
					if record.nil?
						puts "❔  [#{label}]: Not modeled yet, skipping"
						counts[:skipped] += 1
						next
					end

					if !record.real_full_name?
						record.full_name = style[:name]
						puts "✅ [#{label}]: Full name is now #{style[:name].inspect}"
					elsif record.full_name != style[:name]
						puts "⚠️  [#{label}: Full name may have changed, handle manually? " +
							"#{record.full_name.inspect} -> #{style[:name].inspect}"
					end

					if !record.real_thumbnail_url?
						record.thumbnail_url = style[:image]
						puts "✅ [#{label}]: Thumbnail URL is now #{style[:image].inspect}"
					elsif record.thumbnail_url != style[:image]
						puts "⚠️  [#{label}: Thumbnail URL may have changed, handle manually? " +
							"#{record.thumbnail_url.inspect} -> #{style[:image].inspect}"
					end

					if style[:name].end_with?(record.pet_name)
						new_series_name = style[:name].split(record.pet_name).first.strip
						if !record.real_series_name?
							record.series_name = new_series_name
							puts "✅ [#{label}]: Series name is now #{new_series_name.inspect}"
						elsif record.series_name != new_series_name
							if ENV['FORCE'] == '1'
								puts "❗  [#{label}]: Series name forcibly changed: " +
									"#{record.series_name.inspect} -> #{new_series_name.inspect}"
								record.series_name = new_series_name
							else
								puts "⚠️  [#{label}]: Series name may have changed, handle manually? " +
									"#{record.series_name.inspect} -> #{new_series_name.inspect}"
							end
						end
					else
						puts "⚠️  [#{label}]: Unable to detect series name, handle manually? " +
								"#{record.pet_name.inspect} <-> #{style[:name].inspect}"
					end

					if record.changed?
						counts[:changed] += 1
					else
						counts[:unchanged] += 1
					end

					record.save!
				end

				puts "#{group[:label]}: #{counts[:changed]} changed, " +
					"#{counts[:unchanged]} unchanged, #{counts[:skipped]} skipped"
			end
		rescue => e
			puts "Failed to import Styling Studio data: #{e.message}"
			puts e.backtrace.join("\n")
			Sentry.capture_exception(e, tags: { task: "neopets:import:styling_studio" })
			raise
		end
	end
end
