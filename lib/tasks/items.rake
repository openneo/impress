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
end
