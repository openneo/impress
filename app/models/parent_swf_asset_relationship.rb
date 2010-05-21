class ParentSwfAssetRelationship < ActiveRecord::Base
  set_table_name 'parents_swf_assets'
  
  belongs_to :swf_asset
  
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
