class CreateItemOutfitRelationships < ActiveRecord::Migration[4.2]
  def self.up
    create_table :item_outfit_relationships do |t|
      t.integer :item_id
      t.integer :outfit_id
      t.boolean :is_worn

      t.timestamps
    end
  end

  def self.down
    drop_table :item_outfit_relationships
  end
end
