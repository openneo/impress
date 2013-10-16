class AddImageManualToSwfAssets < ActiveRecord::Migration
  def change
    add_column :swf_assets, :image_manual, :boolean, null: false, default: false
  end
end
