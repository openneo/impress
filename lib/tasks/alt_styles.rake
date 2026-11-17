namespace :alt_styles do
	desc "Create/update the token item for every labeled alt style"
	task :sync_token_items => :environment do
		counts = {created: 0, updated: 0, unchanged: 0, skipped: 0}

		AltStyle.includes(:color, :species, :token_item).find_each do |alt_style|
			unless alt_style.labeled?
				counts[:skipped] += 1
				next
			end

			old_item = alt_style.token_item
			old_attributes = old_item&.attributes
			new_item = alt_style.sync_token_item!

			if new_item.nil?
				puts "⚠️  [#{alt_style.id}] Item already exists and is wearable, skipping"
				counts[:skipped] += 1
			elsif old_item.nil?
				puts "✅ [#{alt_style.id}] Created #{new_item.name.inspect}"
				counts[:created] += 1
			elsif new_item.attributes != old_attributes
				puts "✅ [#{alt_style.id}] Updated #{new_item.name.inspect}"
				counts[:updated] += 1
			else
				counts[:unchanged] += 1
			end
		end

		puts "Token items: #{counts[:created]} created, " \
			"#{counts[:updated]} updated, #{counts[:unchanged]} unchanged, " \
			"#{counts[:skipped]} skipped (unlabeled styles, or ID conflicts)"
	end
end
