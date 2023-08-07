class AddImageToOutfits < ActiveRecord::Migration[3.2]
  def self.up
    add_column :outfits, :image, :string
  end

  def self.down
    remove_column :outfits, :image
  end
end
