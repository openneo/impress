class AddHasImageToSwfAssets < ActiveRecord::Migration[3.2]
  def self.up
    add_column :swf_assets, :has_image, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :swf_assets, :has_image
  end
end

