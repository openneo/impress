class PetState < ApplicationRecord
  SwfAssetType = 'biology'
  
  has_many :contributions, :as => :contributed,
    :inverse_of => :contributed # in case of duplicates being merged
  has_many :outfits
  has_many :parent_swf_asset_relationships, :as => :parent,
    :autosave => false
  has_many :swf_assets, :through => :parent_swf_asset_relationships

  belongs_to :pet_type

  delegate :color, to: :pet_type

  alias_method :swf_asset_ids_from_association, :swf_asset_ids
  
  attr_writer :parent_swf_asset_relationships_to_update

  # A simple ordering that tries to bring reliable pet states to the front.
  scope :emotion_order, -> {
    order(Arel.sql(
      "(mood_id IS NULL) ASC, mood_id ASC, female DESC, unconverted DESC, " +
      "glitched ASC, id DESC"
    ))
  }

  # Filter pet states using the "pose" concept we use in the editor.
  scope :with_pose, -> pose {
    case pose
    when "UNCONVERTED"
      where(unconverted: true)
    when "HAPPY_MASC"
      where(mood_id: 1, female: false)
    when "HAPPY_FEM"
      where(mood_id: 1, female: true)
    when "SAD_MASC"
      where(mood_id: 2, female: false)
    when "SAD_FEM"
      where(mood_id: 2, female: true)
    when "SICK_MASC"
      where(mood_id: 4, female: false)
    when "SICK_FEM"
      where(mood_id: 4, female: true)
    when "UNKNOWN"
      where(mood_id: nil).or(where(female: nil))
    else
      raise ArgumentError, "unexpected pose value #{pose}"
    end
  }

  def pose
    if unconverted?
      "UNCONVERTED"
    elsif mood_id.nil? || female.nil?
      "UNKNOWN"
    elsif mood_id == 1 && !female?
      "HAPPY_MASC"
    elsif mood_id == 1 && female?
      "HAPPY_FEM"
    elsif mood_id == 2 && !female?
      "SAD_MASC"
    elsif mood_id == 2 && female?
      "SAD_FEM"
    elsif mood_id == 4 && !female?
      "SICK_MASC"
    elsif mood_id == 4 && female?
      "SICK_FEM"
    else
      raise "could not identify pose: moodId=#{mood_id}, female=#{female}, " +
        "unconverted=#{unconverted}"
    end
  end

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
    self.swf_asset_ids = swf_asset_ids_array.sort.join(',')
  end

  def swf_asset_ids
    self['swf_asset_ids']
  end

  def swf_asset_ids_array
    swf_asset_ids.split(',').map(&:to_i)
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

  def self.from_pet_type_and_biology_info(pet_type, info)
    swf_asset_ids = []
    info.each do |zone_id, asset_info|
      if zone_id.present? && asset_info
        swf_asset_ids << asset_info[:part_id].to_i
      end
    end
    swf_asset_ids_str = swf_asset_ids.sort.join(',')
    if pet_type.new_record?
      pet_state = self.new :swf_asset_ids => swf_asset_ids_str
    else
      pet_state = self.find_or_initialize_by(
        pet_type_id: pet_type.id,
        swf_asset_ids: swf_asset_ids_str
      )
    end
    existing_swf_assets = SwfAsset.biology_assets.includes(:zone).
      where(remote_id: swf_asset_ids)
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
      if zone_id.present? && asset_info
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
end

