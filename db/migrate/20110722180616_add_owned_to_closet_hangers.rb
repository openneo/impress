class AddOwnedToClosetHangers < ActiveRecord::Migration[3.2]
  def self.up
    add_column :closet_hangers, :owned, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :closet_hangers, :owned
  end
end

