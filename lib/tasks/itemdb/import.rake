namespace "itemdb:import" do
	# Series whose styles are named after a character, rather than the pet's
	# color and species: "Essence of Esophagor", "Treasured Roberta".
	CHARACTER_SERIES_NAMES = ["Essence of", "Treasured"]

	desc "Import names and thumbnails for unlabeled alt styles from itemdb"
	task :styles => :environment do
		dry_run = ENV["DRY_RUN"] == "1"
		puts "Importing style tokens from itemdb#{' (DRY RUN)' if dry_run}…"

		# We only ask about styles with no name at all (i.e. ones we've never
		# caught in the Styling Studio), plus named styles whose token is still
		# missing its real description.
		#
		# NOTE: We go by full name here, not `AltStyle.unlabeled`, which goes by
		# series name. Plenty of styles have a full name from the Styling Studio
		# but no series name, because their names don't follow the usual pattern
		# (e.g. "Treasured Roberta"), and those don't need itemdb's help.
		unlabeled_styles = AltStyle.where(full_name: nil, series_name: nil).
			includes(:color, :species).to_a
		undescribed_styles = AltStyle.where.not(full_name: nil).
			or(AltStyle.where.not(series_name: nil)).
			joins(:token_item).where(items: {description: ""}).
			includes(:color, :species, :token_item).to_a
		puts "#{unlabeled_styles.size} unlabeled styles, " \
			"#{undescribed_styles.size} tokens without descriptions"

		# itemdb keeps a list of every style token, which we can load in one
		# well-cached request. It's maintained by hand, though, so for unnamed
		# styles that aren't on it yet, we fall back to looking them up by ID.
		#
		# (The list can also contain the occasional non-token item by mistake.
		# That's okay: we only ever look up our own styles' IDs in it.)
		tokens_by_id = Itemdb.load_style_tokens
		puts "#{tokens_by_id.size} items on itemdb's NC Pet Styles list"

		missing_ids = unlabeled_styles.map(&:id) - tokens_by_id.keys
		if missing_ids.any?
			found = Itemdb.load_items(missing_ids)
			puts "#{missing_ids.size} unnamed styles weren't on the list; " \
				"itemdb knows #{found.size} of them by ID"
			tokens_by_id.merge! found
		end

		counts = {labeled: 0, described: 0, not_found: 0, mismatched: 0}

		unlabeled_styles.each do |style|
			token = tokens_by_id[style.id]
			label = "#{style.pet_name} (#{style.id})"
			if token.nil?
				counts[:not_found] += 1
				next
			end

			# As a sanity check that the item at this ID really is this style's
			# token, we expect its name to follow a pattern we know: ending in the
			# species name, like "Nostalgic Faerie Draik"; or one of the series
			# named after characters, like "Essence of Esophagor". Otherwise, a
			# human should look! (Use FORCE=1 to accept them.)
			species_name = style.species.human_name
			character_series_name = CHARACTER_SERIES_NAMES.find { |series_name|
				token.name.downcase.start_with?("#{series_name.downcase} ")
			}
			unless token.name.downcase.end_with?(species_name.downcase) ||
					character_series_name.present? || ENV["FORCE"] == "1"
				puts "⚠️  [#{label}]: Name doesn't end in #{species_name.inspect}, " \
					"handle manually? #{token.name.inspect}"
				counts[:mismatched] += 1
				next
			end

			style.full_name = token.name
			style.thumbnail_url = token.thumbnail_url
			puts "✅ [#{label}]: Now #{token.name.inspect}"

			# Like in the Styling Studio import, we can only infer the series name
			# when the token name ends in the style's color and species. That's
			# not always so: Neopets reports "Mini Yellow Aisha" as a Blue Aisha,
			# "Celebratory Anniversary" styles as 25th Anniversary, and so on.
			if character_series_name.present?
				style.series_name = character_series_name
				puts "✅ [#{label}]: Series name is now #{style.series_name.inspect}"
			elsif token.name.downcase.end_with?(style.pet_name.downcase)
				style.series_name = token.name[0...-style.pet_name.length].strip
				puts "✅ [#{label}]: Series name is now #{style.series_name.inspect}"
			else
				puts "⚠️  [#{label}]: Unable to detect series name, handle " \
					"manually? #{style.pet_name.inspect} <-> #{token.name.inspect}"
			end
			counts[:labeled] += 1

			# Saving a labeled style also creates its token item.
			style.save! unless dry_run
		end

		(unlabeled_styles + undescribed_styles).each do |style|
			token = tokens_by_id[style.id]
			next if token&.description.blank?

			# Skip styles we just declined to label: they have no token item.
			item = dry_run ? style.token_item : style.reload_token_item
			next if item.nil? || item.description.present?
			next unless item.name == token.name

			puts "✅ [#{item.name} (#{item.id})]: Description is now " \
				"#{token.description.inspect}"
			counts[:described] += 1
			item.update!(description: token.description) unless dry_run
		end

		puts "Styles: #{counts[:labeled]} labeled, " \
			"#{counts[:mismatched]} mismatched, " \
			"#{counts[:not_found]} not on itemdb. " \
			"Tokens: #{counts[:described]} descriptions added."
	end
end
