class AddImageRequestedToSwfAssets < ActiveRecord::Migration
  def self.up
    add_column :swf_assets, :image_requested, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :swf_assets, :image_requested
  end
end

