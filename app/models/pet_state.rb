class PetState < ApplicationRecord
  SwfAssetType = 'biology'

  MAIN_POSES = %w(HAPPY_FEM HAPPY_MASC SAD_FEM SAD_MASC SICK_FEM SICK_MASC)
  
  has_many :contributions, :as => :contributed,
    :inverse_of => :contributed # in case of duplicates being merged
  has_many :outfits
  has_many :parent_swf_asset_relationships, :as => :parent
  has_many :swf_assets, :through => :parent_swf_asset_relationships

  serialize :swf_asset_ids, coder: Serializers::IntegerSet, type: Array

  belongs_to :pet_type

  delegate :species_id, :species, :color_id, :color, to: :pet_type

  alias_method :swf_asset_ids_from_association, :swf_asset_ids

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

  # TODO: More and more, wanting to refactor poses…
  def pose=(pose)
    case pose
    when "UNKNOWN"
      label_pose nil, nil, unconverted: nil, labeled: false
    when "HAPPY_MASC"
      label_pose 1, false
    when "HAPPY_FEM"
      label_pose 1, true
    when "SAD_MASC"
      label_pose 2, false
    when "SAD_FEM"
      label_pose 2, true
    when "SICK_MASC"
      label_pose 4, false
    when "SICK_FEM"
      label_pose 4, true
    when "UNCONVERTED"
      label_pose nil, nil, unconverted: true
    end
  end

  def to_param
    "#{id}-#{pose.split('_').map(&:capitalize).join('-')}"
  end

  # Because our column is named `swf_asset_ids`, we need to ensure writes to
  # it go to the attribute, and not the thing ActiveRecord does of finding the
  # relevant `swf_assets`.
  # TODO: Consider renaming the column to `cached_swf_asset_ids`?
  def swf_asset_ids=(new_swf_asset_ids)
    write_attribute(:swf_asset_ids, new_swf_asset_ids)
  end

  private

  # A helper for the `pose=` method.
  def label_pose(mood_id, female, unconverted: false, labeled: true)
    self.labeled = labeled
    self.mood_id = mood_id
    self.female = female
    self.unconverted = unconverted
  end

  def self.last_updated_key
    PetState.maximum(:updated_at)
  end

  def self.all_supported_poses
    Rails.cache.fetch("PetState.all_supported_poses #{last_updated_key}") do
      {}.tap do |h|
        includes(:pet_type).find_each do |pet_state|
          h[pet_state.species_id] ||= {}
          h[pet_state.species_id][pet_state.color_id] ||= []
          h[pet_state.species_id][pet_state.color_id] << pet_state.pose
        end

        h.values.map(&:values).flatten(1).each(&:uniq!).each(&:sort!)
      end
    end
  end
end

