class AddImageManualToSwfAssets < ActiveRecord::Migration[3.2]
  def change
    add_column :swf_assets, :image_manual, :boolean, null: false, default: false
  end
end
