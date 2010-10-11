class ParentSwfAssetRelationship < ActiveRecord::Base
  set_table_name 'parents_swf_assets'
  
  belongs_to :biology_asset, :class_name => 'SwfAsset', :foreign_key => 'swf_asset_id', :conditions => {:type => 'biology'}
  belongs_to :object_asset, :class_name => 'SwfAsset', :foreign_key => 'swf_asset_id', :conditions => {:type => 'object'}
  
  def swf_asset
    self.swf_asset_type == 'biology' ? self.biology_asset : self.object_asset
  end
  
  def item
    parent
  end
  
  def item=(replacement)
    self.parent_id = replacement.id
  end
  
  def pet_state
    parent
  end
  
  def pet_state=(replacement)
    self.parent_id = replacement.id
  end
end
