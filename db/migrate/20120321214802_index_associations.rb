class IndexAssociations < ActiveRecord::Migration
  def self.up
    add_index :closet_hangers, :item_id
    add_index :closet_hangers, :list_id
    add_index :closet_hangers, :user_id
    
    add_index :closet_lists, :user_id
    
    add_index :contributions, [:contributed_id, :contributed_type]
    add_index :contributions, :user_id
    
    add_index :item_outfit_relationships, :item_id
    add_index :item_outfit_relationships, :outfit_id
    
    add_index :outfits, :pet_state_id
    add_index :outfits, :user_id
    
    remove_index :parents_swf_assets, :name => "parent_swf_assets_parent_id"
    add_index :parents_swf_assets, [:parent_id, :parent_type]
  end

  def self.down
    remove_index :closet_hangers, :item_id
    remove_index :closet_hangers, :list_id
    remove_index :closet_hangers, :user_id
    
    remove_index :closet_lists, :user_id
    
    remove_index :contributions, [:contributed_id, :contributed_type]
    remove_index :contributions, :user_id
    
    remove_index :item_outfit_relationships, :item_id
    remove_index :item_outfit_relationships, :outfit_id
    
    remove_index :outfits, :pet_state_id
    remove_index :outfits, :user_id
    
    add_index "parents_swf_assets", :parent_id, :name => "parent_swf_assets_parent_id"
    remove_index :parents_swf_assets, [:parent_id, :parent_type]
  end
end
