namespace :nc_mall do
	desc "Sync our NCMallRecord table with the live NC Mall"
	task :sync => :environment do
		# Log to STDOUT.
		Rails.logger = Logger.new(STDOUT)

		# First, load all records of what's being sold in the live NC Mall. We load
		# the homepage and all pages linked from the main document, and extract the
		# items from each. (We also de-duplicate the items, which is important
		# because the algorithm expects to only process each item once!)
		pages = load_all_nc_mall_pages
		live_item_records = pages.map { |p| p[:items] }.flatten.uniq

		# Then, get the existing NC Mall records in our database. (We include the
		# items, to be able to output the item name during logging.)
		existing_records = NCMallRecord.includes(:item).all
		existing_records_by_item_id = existing_records.to_h { |r| [r.item_id, r] }

		# Additionally, check which of the item IDs in the live records are items
		# we've seen before. (We'll skip records for items we don't know.)
		live_item_ids = live_item_records.map { |r| r[:id] }
		recognized_item_ids = Item.where(id: live_item_ids).pluck(:id).to_set
		Rails.logger.debug "We found #{live_item_records.size} items, and we " +
			"recognize #{recognized_item_ids.size} of them."

		# For each record in the live NC Mall, check if there's an existing record.
		# If so, update it, and remove it from the existing records hash. If not,
		# create it.
		live_item_records.each do |record_data|
			# If we don't recognize this item ID in our database already, skip it.
			next unless recognized_item_ids.include?(record_data[:id])

			record = existing_records_by_item_id.delete(record_data[:id]) ||
				NCMallRecord.new
			record.item_id = record_data[:id]
			record.price = record_data[:price]
			record.discount_price = record_data.dig(:discount, :price)
			record.discount_begins_at = record_data.dig(:discount, :begins_at)
			record.discount_ends_at = record_data.dig(:discount, :ends_at)

			if !record.changed?
				Rails.logger.info "Skipping record for item #{record_data[:name]} " +
					"(unchanged)"
				next
			end

			if record.save
				if record.previously_new_record?
					Rails.logger.info "Created record for item #{record_data[:name]}"
				else
					Rails.logger.info "Updated record for item #{record_data[:name]}"
				end
			else
				Rails.logger.error "Failed to save record for item " +
					"#{record_data[:name]}: " +
					"#{record.errors.full_messages.join("; ")}: " +
					"#{record.inspect}"
			end
		end

		# For each existing record remaining in the existing records hash, this
		# means there was no live record corresponding to it during this sync.
		# Delete it!
		existing_records_by_item_id.values.each do |record|
			item_name = record.item&.name || "<item not found>"
			if record.destroy
				Rails.logger.info "Destroyed record #{record.id} for item " + 
					"#{item_name}"
			else
				Rails.logger.error "Failed to destroy record #{record.id} for " +
					"item #{item_name}: #{record.inspect}"
			end
		end
	end
end

def load_all_nc_mall_pages
	Sync do
		# First, start loading the homepage.
		homepage_task = Async { NCMall.load_home_page }

		# Next, load the page links for different categories etc.
		links = NCMall.load_page_links

		# Next, load the linked pages, 10 at a time.
		barrier = Async::Barrier.new
		semaphore = Async::Semaphore.new(10, parent: barrier)
		begin
			linked_page_tasks = links.map do |link|
				semaphore.async { NCMall.load_page link[:type], link[:cat] }
			end
			barrier.wait # Load all the pages.
		ensure
			barrier.stop # If any pages failed, cancel the rest.
		end

		# Finally, return all the pages: the homepage, and the linked pages.
		[homepage_task.wait] + linked_page_tasks.map(&:wait)
	end
end
