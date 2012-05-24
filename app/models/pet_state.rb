class PetState < ActiveRecord::Base
  SwfAssetType = 'biology'
  
  has_many :contributions, :as => :contributed # in case of duplicates being merged
  has_many :outfits
  has_many :parent_swf_asset_relationships, :as => :parent,
    :autosave => false
  has_many :swf_assets, :through => :parent_swf_asset_relationships

  belongs_to :pet_type

  alias_method :swf_asset_ids_from_association, :swf_asset_ids
  
  attr_writer :parent_swf_asset_relationships_to_update

  bio_effect_zone_id = 4
  scope :emotion_order, joins(:parent_swf_asset_relationships).
    joins("LEFT JOIN swf_assets effect_assets ON effect_assets.id = parents_swf_assets.swf_asset_id AND effect_assets.zone_id = #{bio_effect_zone_id}").
    group("pet_states.id").
    order("COUNT(effect_assets.remote_id) ASC, COUNT(parents_swf_assets.swf_asset_id) DESC, SUM(parents_swf_assets.swf_asset_id) ASC")

  def reassign_children_to!(main_pet_state)
    self.contributions.each do |contribution|
      contribution.contributed = main_pet_state
      contribution.save
    end
    self.outfits.each do |outfit|
      outfit.pet_state = main_pet_state
      outfit.save
    end
    ParentSwfAssetRelationship.where(ParentSwfAssetRelationship.arel_table[:parent_id].eq(self.id)).delete_all
  end

  def reassign_duplicates!
    raise "This may only be applied to pet states that represent many duplicate entries" unless duplicate_ids
    pet_states = duplicate_ids.split(',').map do |id|
      PetState.find(id.to_i)
    end
    main_pet_state = pet_states.shift
    pet_states.each do |pet_state|
      pet_state.reassign_children_to!(main_pet_state)
      pet_state.destroy
    end
  end

  def sort_swf_asset_ids!
    self.swf_asset_ids = swf_asset_ids.split(',').map(&:to_i).sort.join(',')
  end

  def swf_asset_ids
    self['swf_asset_ids']
  end

  def swf_asset_ids=(ids)
    self['swf_asset_ids'] = ids
  end
  
  def handle_assets!
    @parent_swf_asset_relationships_to_update.each do |rel|
      rel.swf_asset.save!
      rel.save!
    end
  end
  
  def label_by_pet(pet, username)
    # If this pet is already labeled with a gender/mood, or it's unconverted
    # and therefore has none, skip.
    return false if self.labeled? || self.unconverted?
    
    # Find this pet on the owner's userlookup, where we can get both its gender
    # and its mood.
    user_pet = Neopets::User.new(username).pets.
      find { |user_pet| user_pet.name.downcase == pet.name.downcase }
    self.female = user_pet.female?
    self.mood_id = user_pet.mood.id
    self.labeled = true
    
    true
  end
  
  def mood
    Neopets::Pet::Mood.find(self.mood_id)
  end

  def self.from_pet_type_and_biology_info(pet_type, info)
    swf_asset_ids = []
    info.each do |zone_id, asset_info|
      if asset_info
        swf_asset_ids << asset_info[:part_id].to_i
      end
    end
    swf_asset_ids_str = swf_asset_ids.sort.join(',')
    if pet_type.new_record?
      pet_state = self.new :swf_asset_ids => swf_asset_ids_str
    else
      pet_state = self.find_or_initialize_by_pet_type_id_and_swf_asset_ids(
          pet_type.id,
          swf_asset_ids_str
        )
    end
    existing_swf_assets = SwfAsset.biology_assets.find_all_by_remote_id(swf_asset_ids)
    existing_swf_assets_by_id = {}
    existing_swf_assets.each do |swf_asset|
      existing_swf_assets_by_id[swf_asset.remote_id] = swf_asset
    end
    existing_relationships_by_swf_asset_id = {}
    unless pet_state.new_record?
      pet_state.parent_swf_asset_relationships.each do |relationship|
        existing_relationships_by_swf_asset_id[relationship.swf_asset_id] = relationship
      end
    end
    pet_state.pet_type = pet_type # save the second case from having to look it up by ID
    relationships = []
    info.each do |zone_id, asset_info|
      if asset_info
        swf_asset_id = asset_info[:part_id].to_i
        swf_asset = existing_swf_assets_by_id[swf_asset_id]
        unless swf_asset
          swf_asset = SwfAsset.new
          swf_asset.remote_id = swf_asset_id
        end
        swf_asset.origin_biology_data = asset_info
        swf_asset.origin_pet_type = pet_type
        relationship = existing_relationships_by_swf_asset_id[swf_asset.id]
        unless relationship
          relationship ||= ParentSwfAssetRelationship.new
          relationship.parent = pet_state
          relationship.swf_asset_id = swf_asset.id
        end
        relationship.swf_asset = swf_asset
        relationships << relationship
      end
    end
    pet_state.parent_swf_asset_relationships_to_update = relationships
    pet_state.unconverted = (relationships.size == 1)
    pet_state
  end

  def self.repair_all!
    self.transaction do
      self.all.each do |pet_state|
        pet_state.sort_swf_asset_ids!
        pet_state.save
      end

      self.
        select('pet_states.pet_type_id, pet_states.swf_asset_ids, GROUP_CONCAT(DISTINCT pet_states.id) AS duplicate_ids').
        joins('INNER JOIN pet_states ps2 ON pet_states.pet_type_id = ps2.pet_type_id AND pet_states.swf_asset_ids = ps2.swf_asset_ids').
        group('pet_states.pet_type_id, pet_states.swf_asset_ids').
        having('count(*) > 1').
        all.
      each do |pet_state|
        pet_state.reassign_duplicates!
      end
    end
  end
end

