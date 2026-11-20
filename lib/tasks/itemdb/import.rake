namespace "itemdb:import" do
	desc "Import alt style names, thumbnails, and token descriptions from itemdb"
	task :styles => :environment do
		dry_run = ENV["DRY_RUN"] == "1"
		puts "Importing style tokens from itemdb#{' (DRY RUN)' if dry_run}…"

		# We ask about styles with no name at all (i.e. ones we've never caught in
		# the Styling Studio), and also check our named styles against itemdb, in
		# case Neopets has renamed them since we last saw them.
		#
		# NOTE: We go by full name here, not `AltStyle.unlabeled`, which goes by
		# series name. Plenty of styles have a full name from the Styling Studio
		# but no series name, because their names don't follow the usual pattern
		# (e.g. "Treasured Roberta"), and those don't need itemdb's help.
		unlabeled_styles = AltStyle.where(full_name: nil, series_name: nil).
			includes(:color, :species).to_a
		named_styles = AltStyle.where.not(full_name: nil).
			or(AltStyle.where.not(series_name: nil)).
			includes(:color, :species, :token_item).to_a
		puts "#{unlabeled_styles.size} unlabeled styles, " \
			"#{named_styles.size} named styles"

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

		counts = {labeled: 0, described: 0, not_found: 0, mismatched: 0,
			renamed: 0, rename_mismatched: 0}

		# The styles we've labeled or renamed. (In a dry run, we don't save them,
		# so their token items keep their old names.)
		changed_styles = Set.new
		save_style = ->(style) {
			changed_styles << style
			style.save! unless dry_run
		}

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
			series_name = style.infer_series_name(token.name)
			unless token.name.downcase.end_with?(species_name.downcase) ||
					series_name.present? || ENV["FORCE"] == "1"
				puts "⚠️  [#{label}]: Name doesn't end in #{species_name.inspect}, " \
					"handle manually? #{token.name.inspect}"
				counts[:mismatched] += 1
				next
			end

			style.full_name = token.name
			style.thumbnail_url = token.thumbnail_url
			puts "✅ [#{label}]: Now #{token.name.inspect}"

			if series_name.present?
				style.series_name = series_name
				puts "✅ [#{label}]: Series name is now #{style.series_name.inspect}"
			else
				puts "⚠️  [#{label}]: Unable to detect series name, handle " \
					"manually? #{style.pet_name.inspect} <-> #{token.name.inspect}"
			end
			counts[:labeled] += 1

			# Saving a labeled style also creates its token item.
			save_style.(style)
		end

		# Neopets sometimes renames style tokens after release: the 2024 Nostalgic
		# Faerie Gnorbu is now the Fluttering Faerie Gnorbu, alongside the rest of
		# the Fluttering Faerie series. The Styling Studio import only warns about
		# changes like that, so we'd stay out of date (and the old thumbnail URL
		# can stop working, too).
		#
		# itemdb gets its item names from Neopets, so when we disagree, we take
		# theirs, along with its thumbnail. But only when we can tell the new name
		# is for the same pet: it still ends in this style's color and species, or
		# only differs from ours in capitalization. (Or, for series named after
		# characters, which don't name the species, the style is already in that
		# series.) Otherwise, a human should look! (FORCE=1 doesn't apply here:
		# these styles already have names, and we'd rather not overwrite them with
		# anything we can't double-check.)
		#
		# We update the series name to match, when we can tell what it is. When we
		# can't, we keep ours: the series is our own grouping, not Neopets's. For
		# example, Neopets renamed "Prismatic Cocoa: Nostalgic Christmas Acara" to
		# "Prismatic Cocoa: Christmas Acara", but it's still a recolor of the
		# Nostalgic Christmas style, so it stays in "Prismatic Cocoa: Nostalgic".
		#
		# NOTE: This means itemdb wins over our own names, including ones a human
		# set by hand. If we ever get ahead of itemdb, we'll go back to their name
		# until they catch up.
		named_styles.each do |style|
			token = tokens_by_id[style.id]
			next if token.nil? || token.name == style.full_name

			label = "#{style.full_name} (#{style.id})"
			series_name = style.infer_series_name(token.name)
			same_pet = series_name.present? ||
				token.name.downcase.end_with?(" #{style.pet_name.downcase}") ||
				token.name.casecmp?(style.full_name)
			changes_character_series =
				AltStyle::CHARACTER_SERIES_NAMES.include?(series_name) &&
				series_name != style.real_series_name
			if !same_pet || changes_character_series
				puts "⚠️  [#{label}]: itemdb calls it #{token.name.inspect}, but " \
					"we can't tell it's the same pet, handle manually?"
				counts[:rename_mismatched] += 1
				next
			end

			style.full_name = token.name
			style.series_name = series_name if series_name.present?
			style.thumbnail_url = token.thumbnail_url
			puts "✏️  [#{label}]: Renamed to #{token.name.inspect}, " \
				"#{series_name.present? ? 'in' : 'keeping'} series " \
				"#{style.real_series_name.inspect}"
			counts[:renamed] += 1

			# Saving the style also renames its token item.
			save_style.(style)
		end

		(unlabeled_styles + named_styles).each do |style|
			token = tokens_by_id[style.id]
			next if token&.description.blank?

			# Skip styles we just declined to label: they have no token item.
			changed = changed_styles.include?(style)
			item = changed && !dry_run ? style.reload_token_item : style.token_item
			next if item.nil? || item.description.present?

			# Only describe the item if it's really this token. (If we just renamed
			# the style in a dry run, the item still has its old name, so we check
			# the style's name instead: saving it would have renamed the item.)
			item_name = changed && dry_run ? style.full_name : item.name
			next unless item_name == token.name

			puts "✅ [#{token.name} (#{item.id})]: Description is now " \
				"#{token.description.inspect}"
			counts[:described] += 1
			item.update!(description: token.description) unless dry_run
		end

		puts "Styles: #{counts[:labeled]} labeled, " \
			"#{counts[:mismatched]} mismatched, " \
			"#{counts[:not_found]} not on itemdb, " \
			"#{counts[:renamed]} renamed, " \
			"#{counts[:rename_mismatched]} renames to check by hand. " \
			"Tokens: #{counts[:described]} descriptions added."
	end
end
