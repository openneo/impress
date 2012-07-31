class AddImageLayersHashToOutfit < ActiveRecord::Migration
  def self.up
    add_column :outfits, :image_layers_hash, :string, :length => 8
  end

  def self.down
    remove_column :outfits, :image_layers_hash
  end
end
