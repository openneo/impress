class TreatSoldInMallAsABoolean < ActiveRecord::Migration
  def self.up
    change_column :objects, :sold_in_mall, :boolean, :null => false
  end

  def self.down
    change_column :objects, :sold_in_mall, :integer, :limit => 1, :null => false
  end
end
