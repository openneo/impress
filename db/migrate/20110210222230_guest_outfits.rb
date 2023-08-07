class GuestOutfits < ActiveRecord::Migration[3.2]
  def self.up
    change_column :outfits, :name, :string, :null => true
  end

  def self.down
    change_column :outfits, :name, :string, :null => false
  end
end
