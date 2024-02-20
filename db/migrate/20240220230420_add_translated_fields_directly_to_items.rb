class AddTranslatedFieldsDirectlyToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :name, :string, null: false
    add_column :items, :description, :text, null: false, default: ""
    add_column :items, :rarity, :string, null: false, default: ""

    reversible do |direction|
      direction.up do
        total_count = Item.count
        saved_count = 0
        Item.includes(:translations).find_in_batches do |items|
          Item.transaction do
            items.each do |item|
              item.name = item.translation_for(:en).name
              item.description = item.translation_for(:en).description || ""
              item.rarity = item.translation_for(:en).rarity || ""
              item.save!
            end
            saved_count += items.size
            puts "Saved #{saved_count} of #{total_count} items"
          end
        end
      end
    end
  end
end
