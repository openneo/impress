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

  # Our ideal order is: happy, sad, sick, UC, any+effects, glitched, with male
  # before female within those groups for consistency. We therefore order as
  # follows, listed in order of priority:
  # * Send glitched states to the back
  # * Bring known happy states to the front (we don't want to sort by mood_id
  #   DESC first because then labeled sad will appear before unlabeled happy)
  # * Send states with effect assets to the back
  # * Bring state with more assets forward (that is, send UC near the back)
  # * Bring males forward
  # * Bring states with a lower asset ID sum forward (the idea being that
  #   sad/female states are usually created after a happy/male base, but that's
  #   becoming increasingly untrue over time - this is a very last resort)
  #
  # Maybe someday, when most states are labeled, we can depend exclusively on
  # their labels - or at least use more than is-happy and is-female. For now,
  # though, this strikes a good balance of bringing default to the front for
  # many pet types (the highest priority!) and otherwise doing decent sorting.
  bio_effect_zone_id = 4
  scope :emotion_order, -> {
    joins(:parent_swf_asset_relationships).
    joins("LEFT JOIN swf_assets effect_assets ON effect_assets.id = parents_swf_assets.swf_asset_id AND effect_assets.zone_id = #{bio_effect_zone_id}").
    group("pet_states.id").
    order(Arel.sql("glitched ASC, (mood_id = 1) DESC, COUNT(effect_assets.remote_id) ASC, COUNT(parents_swf_assets.swf_asset_id) DESC, female ASC, SUM(parents_swf_assets.swf_asset_id) ASC"))
  }

  def as_json(options={})
    {
      id: id,
      gender_mood_description: gender_mood_description,
      swf_asset_ids: swf_asset_ids_array,
      artist_name: artist_name,
      artist_url: artist_url
    }
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
  
  def mood
    Mood.find(self.mood_id)
  end
  
  def gender_name
    if female?
      I18n.translate("pet_states.description.gender.female")
    else
      I18n.translate("pet_states.description.gender.male")
    end
  end
  
  def mood_name
    I18n.translate("pet_states.description.mood.#{mood.name}")
  end
  
  def gender_mood_description
    if glitched?
      I18n.translate('pet_states.description.glitched')
    elsif unconverted?
      I18n.translate('pet_states.description.unconverted')
    elsif labeled?
      I18n.translate('pet_states.description.main', :gender => gender_name,
                     :mood => mood_name)
    else
      I18n.translate('pet_states.description.unlabeled')
    end
  end

  def replace_with(other)
    PetState.transaction do
      count = outfits.count
      outfits.find_each { |outfit|
        outfit.pet_state = other
        outfit.save!
      }
      destroy
    end
    count
  end

  def artist_name
    artist_neopets_username || I18n.translate("pet_states.default_artist_name")
  end

  def artist_url
    if artist_neopets_username
      "https://www.neopets.com/userlookup.phtml?user=#{artist_neopets_username}"
    else
      nil
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

  # Copied from https://github.com/matchu/neopets/blob/5d13a720b616ba57fbbd54541f3e5daf02b3fedc/lib/neopets/pet/mood.rb
  class Mood
    attr_reader :id, :name
    
    def initialize(options)
      @id = options[:id]
      @name = options[:name]
    end
    
    def self.find(id)
      self.all_by_id[id.to_i]
    end
    
    def self.all
      @all ||= [
        Mood.new(:id => 1, :name => :happy),
        Mood.new(:id => 2, :name => :sad),
        Mood.new(:id => 4, :name => :sick)
      ]
    end
    
    def self.all_by_id
      @all_by_id ||= self.all.inject({}) { |h, m| h[m.id] = m; h }
    end
  end
end

