class AddImageToOutfits < ActiveRecord::Migration[4.2]
  def self.up
    add_column :outfits, :image, :string
  end

  def self.down
    remove_column :outfits, :image
  end
end
