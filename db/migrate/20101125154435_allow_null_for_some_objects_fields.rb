class AllowNullForSomeObjectsFields < ActiveRecord::Migration
  def self.up
    change_column :objects, :category, :string, :limit => 50, :null => true
    change_column :objects, :type, :string, :limit => 50, :null => true
    change_column :objects, :rarity, :string, :limit => 25, :null => true
    change_column :objects, :rarity_index, :integer, :limit => 2, :null => true
    change_column :objects, :weight_lbs, :integer, :limit => 2, :null => true
  end

  def self.down
    change_column :objects, :category, :string, :limit => 50, :null => false
    change_column :objects, :type, :string, :limit => 50, :null => false
    change_column :objects, :rarity, :string, :limit => 25, :null => false
    change_column :objects, :rarity_index, :integer, :limit => 2, :null => false
    change_column :objects, :weight_lbs, :integer, :limit => 2, :null => false
  end
end
