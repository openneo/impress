class AddImageRequestedToSwfAssets < ActiveRecord::Migration[4.2]
  def self.up
    add_column :swf_assets, :image_requested, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :swf_assets, :image_requested
  end
end

