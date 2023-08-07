class AddNameAndStarredToOutfits < ActiveRecord::Migration[4.2]
  def self.up
    add_column :outfits, :name, :string, :null => false
    add_column :outfits, :starred, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :outfits, :starred
    remove_column :outfits, :name
  end
end
