class AddSwfAssetsTypeAndIdIndex < ActiveRecord::Migration[3.2]
  def self.up
    add_index "swf_assets", ["type", "id"], :name => "swf_assets_type_and_id"
  end

  def self.down
    remove_index "swf_assets", :name => "swf_assets_type_and_id"
  end
end
