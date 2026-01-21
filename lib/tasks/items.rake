namespace :items do
	desc "Update cached fields for all items (useful if logic changes)"
	task :update_cached_fields => :environment do
		puts "Updating cached item fields for all items…"
		Item.includes(:swf_assets).find_in_batches.with_index do |items, batch|
			puts "Updating item batch ##{batch+1}…"
			Item.transaction do
				items.each(&:update_cached_fields)
			end
		end
	end

	desc "Auto-model items on missing body types using NC Mall preview API"
	task :auto_model, [:limit] => :environment do |task, args|
		limit = (args[:limit] || 100).to_i
		dry_run = ENV["DRY_RUN"] == "1"
		auto_hint = ENV["AUTO_HINT"] != "0"

		puts "Auto-modeling up to #{limit} items#{dry_run ? ' (DRY RUN)' : ''}..."
		puts "Auto-hint: #{auto_hint ? 'enabled' : 'disabled'}"
		puts

		# Find items that need modeling, newest first
		items = Item.is_not_modeled.order(created_at: :desc).limit(limit)
		puts "Found #{items.count} items to process"
		puts

		items.each_with_index do |item, index|
			puts "[#{index + 1}/#{items.count}] Item ##{item.id}: #{item.name}"

			missing_body_ids = item.predicted_missing_body_ids
			if missing_body_ids.empty?
				puts "  ⚠️  No missing body IDs (item may already be fully modeled)"
				puts
				next
			end

			puts "  Missing #{missing_body_ids.size} body IDs: #{missing_body_ids.join(', ')}"

			# Track results for this item
			results = {modeled: 0, not_compatible: 0, not_found: 0}
			had_transient_error = false

			missing_body_ids.each do |body_id|
				if dry_run
					puts "    Body #{body_id}: [DRY RUN] would attempt modeling"
					next
				end

				begin
					result = Pet::AutoModeling.model_item_on_body(item, body_id)
					results[result] += 1

					case result
					when :modeled
						puts "    Body #{body_id}: ✅ Modeled successfully"
					when :not_compatible
						puts "    Body #{body_id}: ❌ Not compatible (heuristic over-predicted)"
					end
				rescue Pet::AutoModeling::NoPetTypeForBody => e
					puts "    Body #{body_id}: ⚠️  #{e.message}"
				rescue Neopets::NCMall::ResponseNotOK => e
					if e.status >= 500
						puts "    Body #{body_id}: ⚠️  Server error (#{e.status}), will retry later"
						had_transient_error = true
					else
						puts "    Body #{body_id}: ❌ HTTP error (#{e.status})"
						Sentry.capture_exception(e)
					end
				rescue Neopets::NCMall::UnexpectedResponseFormat => e
					puts "    Body #{body_id}: ❌ Unexpected response format: #{e.message}"
					Sentry.capture_exception(e)
				rescue Neopets::CustomPets::DownloadError => e
					puts "    Body #{body_id}: ⚠️  AMF error: #{e.message}"
					had_transient_error = true
				end
			end

			unless dry_run
				# Set hint if we've addressed all bodies without transient errors.
				# That way, if the item is not compatible with some bodies, we'll stop
				# trying to auto-model it.
				if auto_hint && !had_transient_error
					item.update!(modeling_status_hint: "done")
					puts "  📋 Set modeling_status_hint = 'done'"
				end
			end

			puts "  Summary: #{results[:modeled]} modeled, #{results[:not_compatible]} not compatible, #{results[:not_found]} not found"
			puts

			# Be nice to Neopets API
			sleep 0.5 unless dry_run || index == items.count - 1
		end

		puts "Done!"
	end
end
