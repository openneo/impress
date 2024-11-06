class ParentSwfAssetRelationship < ApplicationRecord
  self.table_name = 'parents_swf_assets'
  
  belongs_to :parent, polymorphic: true
  
  belongs_to :swf_asset

  after_save :update_parent_cached_fields
  after_destroy :update_parent_cached_fields
  
  def item=(replacement)
    self.parent = replacement
  end
  
  def pet_state
    PetState.find(parent_id)
  end
  
  def pet_state=(replacement)
    self.parent = replacement
  end

  def update_parent_cached_fields
    parent.try(:update_cached_fields!)
  end
end
