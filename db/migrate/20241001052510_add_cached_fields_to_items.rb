class AddCachedFieldsToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :cached_occupied_zone_ids, :string, null: false, default: ""
    add_column :items, :cached_compatible_body_ids, :text, null: false, default: ""

    reversible do |direction|
      direction.up do
        puts "Updating cached item fields for all items…"
        Item.includes(:swf_assets).find_in_batches.with_index do |items, batch|
          puts "Updating item batch ##{batch+1}…"
          items.each(&:update_cached_fields)
        end
      end
    end
  end
end
