class ParentSwfAssetRelationship < ActiveRecord::Base
  set_table_name 'parents_swf_assets'
  
  belongs_to :parent, :class_name => 'Item'
  belongs_to :swf_asset
  
  default_scope where(Table('parents_swf_assets')[:swf_asset_type].eq('object'))
  
  def item
    parent
  end
  
  def item=(replacement)
    self.parent = replacement
  end
end
