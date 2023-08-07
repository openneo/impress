class AddVisibilityToClosetLists < ActiveRecord::Migration[3.2]
  def self.up
    add_column :closet_lists, :visibility, :integer, :null => false, :default => 1
  end

  def self.down
    remove_column :closet_lists, :visibility
  end
end

