class IndexClosetHangerQuery2 < ActiveRecord::Migration
  def self.up
    # SELECT `objects`.* FROM `objects`
    # INNER JOIN `item_outfit_relationships` ON
    #   `objects`.id = `item_outfit_relationships`.item_id
    # WHERE ((`item_outfit_relationships`.outfit_id = 138510) AND
    #   ((`item_outfit_relationships`.`is_worn` = 1)));
    
    # Small optimization, but an optimization nonetheless!
    # Note that MySQL indexes can be reused for left-subsets, by which I mean
    # this index can also act as just an index for outfit_id. Neat, eh?
    remove_index :item_outfit_relationships, :outfit_id
    add_index :item_outfit_relationships, [:outfit_id, :is_worn]
  end

  def self.down
    remove_index :item_outfit_relationships, [:outfit_id, :is_worn]
    add_index :item_outfit_relationships, :outfit_id
  end
end
