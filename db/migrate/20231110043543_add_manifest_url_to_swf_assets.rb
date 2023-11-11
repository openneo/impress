class AddManifestUrlToSwfAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :swf_assets, :manifest_url, :string
  end
end
