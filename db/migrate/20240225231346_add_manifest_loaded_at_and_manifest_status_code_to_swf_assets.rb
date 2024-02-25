class AddManifestLoadedAtAndManifestStatusCodeToSwfAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :swf_assets, :manifest_loaded_at, :datetime
    add_column :swf_assets, :manifest_status_code, :integer
  end
end
