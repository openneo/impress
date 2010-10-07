class PetState < ActiveRecord::Base
  SwfAssetType = 'biology'
  
  has_many :parent_swf_asset_relationships, :foreign_key => 'parent_id',
    :conditions => {:swf_asset_type => SwfAssetType}
  has_many :swf_assets, :through => :parent_swf_asset_relationships
  
  belongs_to :pet_type
  
  alias_method :swf_asset_ids_from_association, :swf_asset_ids
  
  def swf_asset_ids
    self['swf_asset_ids']
  end
  
  def swf_asset_ids=(ids)
    self['swf_asset_ids'] = ids
  end
  
  def self.from_pet_type_and_biology_info(pet_type, info)
    swf_asset_ids = []
    info.each do |asset_info|
      if asset_info
        swf_asset_ids << asset_info[:part_id].to_i
      end
    end
    swf_asset_ids_str = swf_asset_ids.join(',')
    if pet_type.new_record?
      pet_state = self.new :swf_asset_ids => swf_asset_ids_str
    else
      pet_state = self.find_or_initialize_by_pet_type_id_and_swf_asset_ids(
          pet_type.id,
          swf_asset_ids_str
        )
    end
    existing_swf_assets = SwfAsset.find_all_by_id(swf_asset_ids)
    existing_swf_assets_by_id = {}
    existing_swf_assets.each do |swf_asset|
      existing_swf_assets_by_id[swf_asset.id] = swf_asset
    end
    existing_relationships_by_swf_asset_id = {}
    unless pet_state.new_record?
      pet_state.parent_swf_asset_relationships.each do |relationship|
        existing_relationships_by_swf_asset_id[relationship.swf_asset_id] = relationship
      end
    end
    pet_state.pet_type = pet_type # save the second case from having to look it up by ID
    relationships = []
    info.each do |asset_info|
      if asset_info
        swf_asset_id = asset_info[:part_id].to_i
        swf_asset = existing_swf_assets_by_id[swf_asset_id]
        unless swf_asset
          swf_asset = SwfAsset.new
          swf_asset.id = swf_asset_id
        end
        swf_asset.origin_biology_data = asset_info
        swf_asset.origin_pet_type = pet_type
        relationship = existing_relationships_by_swf_asset_id[swf_asset_id]
        unless relationship
          relationship ||= ParentSwfAssetRelationship.new
          relationship.parent_id = pet_state.id
          relationship.swf_asset_type = SwfAssetType
          relationship.swf_asset_id = swf_asset.id
        end
        relationship.swf_asset = swf_asset
        relationships << relationship
      end
    end
    pet_state.parent_swf_asset_relationships = relationships
    pet_state
  end
end
