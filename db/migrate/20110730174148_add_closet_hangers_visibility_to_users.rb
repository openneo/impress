class AddClosetHangersVisibilityToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :owned_closet_hangers_visibility, :integer, :null => false, :default => 1
    add_column :users, :wanted_closet_hangers_visibility, :integer, :null => false, :default => 1
  end

  def self.down
    remove_column :users, :wanted_closet_hangers_visibility
    remove_column :users, :owned_closet_hangers_visibility
  end
end

