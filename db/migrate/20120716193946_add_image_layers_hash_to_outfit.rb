class AddImageLayersHashToOutfit < ActiveRecord::Migration[4.2]
  def self.up
    add_column :outfits, :image_layers_hash, :string, :length => 8
  end

  def self.down
    remove_column :outfits, :image_layers_hash
  end
end
