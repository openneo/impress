class GuestOutfits < ActiveRecord::Migration
  def self.up
    change_column :outfits, :name, :string, :null => true
  end

  def self.down
    change_column :outfits, :name, :string, :null => false
  end
end
