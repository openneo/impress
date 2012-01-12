class RenameSwfAssetsIdToRemoteId < ActiveRecord::Migration
  def self.up
    rename_column :swf_assets, :id, :remote_id
    add_column    :swf_assets, :id, :primary_key
    
    Contribution.where(:contributed_type => 'SwfAsset').find_each do |c|
      # Use real IDs instead of remote IDs
      swf_asset = SwfAsset.object_assets.
        find_by_remote_id(c.contributed_id)
      c.contributed_id = swf_asset.id
      c.save!
    end
    puts "Updated contributions"

    add_column :parents_swf_assets, :id, :primary_key
    add_column :parents_swf_assets, :parent_type, :string, :null => false,
      :limit => 8
    ParentSwfAssetRelationship.all.each do |rel|
      swf_asset = SwfAsset.where(:type => rel.swf_asset_type).
        find_by_remote_id(rel.swf_asset_id)
      rel.swf_asset_id = swf_asset.id
      rel.parent_type = (rel.swf_asset_type == 'biology') ? 'PetState' : 'Item'
      rel.save!
    end
    puts "Updated parent/asset relationships"
    
    remove_column :parents_swf_assets, :swf_asset_type
  end

  def self.down
    add_column :parents_swf_assets, :swf_asset_type, :string,
      :null => false, :limit => 7
    
    ParentSwfAssetRelationship.all.each do |rel|
      swf_asset = SwfAsset.find(rel.swf_asset_id)
      rel.swf_asset_id   = swf_asset.remote_id
      rel.swf_asset_type = swf_asset.type
      rel.save!
    end
    remove_column :parents_swf_assets, :parent_type
    remove_column :parents_swf_assets, :id
    puts "Updated parent/asset relationships"
    
    Contribution.where(:contributed_type => 'SwfAsset').find_each do |c|
      # Use remote IDs instead of real IDs
      swf_asset = SwfAsset.find(c.swf_asset_id)
      c.contributed_id = swf_asset.remote_id
      c.save!
    end
    puts "Updated contributions"
    
    remove_column :swf_assets, :id
    rename_column :swf_assets, :remote_id, :id
  end
end
