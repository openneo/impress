class AddDescriptionToObjects < ActiveRecord::Migration
  def self.up
    add_column :objects, :description, :text
  end

  def self.down
    remove_column :objects, :description
  end
end
