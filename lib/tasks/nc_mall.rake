namespace :nc_mall do
	desc "Sync our NCMallRecord table with the live NC Mall"
	task :sync => :environment do
		# Log to STDOUT.
		Rails.logger = Logger.new(STDOUT)

		# First, load all records of what's being sold in the live NC Mall.
		# TODO: Load from other pages, too!
		live_item_records = NCMall.load_home_page[:items]

		# Then, get the existing NC Mall records in our database. (We include the
		# items, to be able to output the item name during logging.)
		existing_records = NCMallRecord.includes(:item).all
		existing_records_by_item_id = existing_records.to_h { |r| [r.item_id, r] }

		# Additionally, check which of the item IDs in the live records are items
		# we've seen before. (We'll skip records for items we don't know.)
		live_item_ids = live_item_records.map { |r| r[:id] }
		recognized_item_ids = Item.where(id: live_item_ids).pluck(:id).to_set
		Rails.logger.debug "We recognize #{recognized_item_ids.size} of these items"

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
			if record.save
				Rails.logger.info "Saved record for item #{record_data[:name]}"
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
