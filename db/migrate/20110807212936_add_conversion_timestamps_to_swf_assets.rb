class AddConversionTimestampsToSwfAssets < ActiveRecord::Migration[3.2]
  def self.up
    add_column :swf_assets, :reported_broken_at, :timestamp
    add_column :swf_assets, :converted_at, :timestamp
  end

  def self.down
    remove_column :swf_assets, :converted_at
    remove_column :swf_assets, :reported_broken_at
  end
end
