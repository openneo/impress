class AddCachedPredictedFullyModeledToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :cached_predicted_fully_modeled, :boolean,
      default: false, null: false

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
