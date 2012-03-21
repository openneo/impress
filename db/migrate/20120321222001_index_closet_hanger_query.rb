class IndexClosetHangerQuery < ActiveRecord::Migration
  def self.up
    # SELECT COUNT(DISTINCT `closet_hangers`.`id`) FROM `closet_hangers` INNER
    # JOIN `users` ON `users`.`id` = `closet_hangers`.`user_id` LEFT OUTER JOIN
    # `closet_lists` ON `closet_lists`.`id` = `closet_hangers`.`list_id` WHERE
    # `closet_hangers`.`owned` = XXX AND (`closet_hangers`.item_id = XXX) AND
    # ((`closet_hangers`.`list_id` IS NULL AND
    # `users`.`owned_closet_hangers_visibility` >= XXX OR
    # `closet_lists`.`visibility` >= XXX));
    
    # It's not a huge improvement over the association index, but it's nice to
    # be able to scan fewer rows for so little penalty, right?
    
    remove_index :closet_hangers, :item_id
    add_index :closet_hangers, [:item_id, :owned]
  end

  def self.down
    remove_index :closet_hangers, [:item_id, :owned]
    add_index :closet_hangers, :item_id
  end
end
