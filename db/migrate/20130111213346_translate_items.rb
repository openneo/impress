class TranslateItems < ActiveRecord::Migration[4.2]
  def self.up
    rename_table :objects, :items
    Item.create_translation_table!({
      :name => :string,
      :description => :text,
      :rarity => :string
    }, {
      :migrate_data => true
    })
  end

  def self.down
    Item.drop_translation_table! :migrate_data => true
    rename_table :items, :objects
  end
end
