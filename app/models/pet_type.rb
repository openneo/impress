class PetType < ApplicationRecord
  # NOTE: While a pet type does always functionally belong to a color and
  # species, sometimes we don't have that record yet, in which case color_id
  # or species_id will refer to a nonexistant record, and the site should
  # generally fall back gracefully about that.
  belongs_to :species, optional: true
  belongs_to :color, optional: true
  has_one :contribution, :as => :contributed, :inverse_of => :contributed
  has_many :pet_states
  has_many :pets

  scope :basic, -> { joins(:color).merge(Color.basic) }
  scope :matching_name, ->(color_name, species_name) {
    color = Color.find_by_name!(color_name)
    species = Species.find_by_name!(species_name)
    where(color_id: color.id, species_id: species.id)
  }
  scope :newest, -> { order(created_at: :desc) }
  scope :preferring_species, ->(species_id) {
    joins(:species).order([Arel.sql("species_id = ? DESC"), species_id])
  }
  scope :preferring_color, ->(color_id) {
    joins(:color).order([Arel.sql("color_id = ? DESC"), color_id])
  }
  scope :preferring_simple, -> {
    joins(:species, :color).
      merge(Species.order(name: :asc)).
      merge(Color.order(basic: :desc, standard: :desc, name: :asc))
  }
  scope :released_before, ->(time) {
    # We use DTI's creation timestamp as an estimate of when it was released.
    where('created_at <= ?', time)
  }

  def self.random_basic_per_species(species_ids)
    random_pet_types = []
    basics_by_species_id = basic.group_by(&:species_id)
    species_ids.each do |species_id|
      pet_types = basics_by_species_id[species_id]
      random_pet_types << pet_types[rand(pet_types.size)] if pet_types
    end
    random_pet_types
  end

  def as_json(options={})
    super({
      only: [:id],
      methods: [:color, :species]
    }.merge(options))
  end

  def image_hash
    # If there's a known basic image hash (no clothes), use that.
    # Otherwise, if we have some image of a pet that we've picked up, use that.
    # Otherwise, refer to the fallback YAML file (though, if we have our
    # basic image hashes set correctly, the fallbacks should just be an old
    # subset of the basic image hashes in the database.)
    basic_image_hash || self['image_hash'] || 'deadbeef'
  end

  def consider_pet_image(pet_name)
    # If we already have a basic image hash, don't worry about it!
    return if basic_image_hash?

    # Otherwise, use this as the new image hash for this pet type.
    self.image_hash = Neopets::CustomPets.fetch_image_hash(pet_name)
  end

  def possibly_new_color
    self.color || Color.new(id: self.color_id)
  end

  def possibly_new_species
    self.species || Species.new(id: self.species_id)
  end

  def human_name
    I18n.translate('pet_types.human_name',
                   color_human_name: possibly_new_color.human_name,
                   species_human_name: possibly_new_species.human_name)
  end

  def canonical_pet_state
    # For consistency (randomness is always scary!), we use the PetType ID to
    # determine which gender to prefer, if it's not built into the color. That
    # way, it'll be stable, but we'll still get the *vibes* of randomness.
    preferred_gender = color.default_gender_presentation ||
      (id % 2 == 0 ? :fem : :masc)

    # NOTE: If this were only being called on one pet type at a time, it would
    # be more efficient to send this as a single query with an `order` part and
    # just get the first record. But we most importantly call this on all the
    # pet types for a single color at once, in which case it's better for the
    # caller to use `includes(:pet_states)` to preload the pet states then sort
    # then in Ruby here, rather than send ~50 queries. Also, there's generally
    # very few pet states per pet type, so the perf difference is negligible.
    pet_states.sort_by { |pet_state|
      gender = pet_state.female? ? :fem : :masc
      [
        # We prefer labeled pet states first, because states no one has seen or
        # validated are such a wildcard! Then we prefer unglitched, then we
        # prefer maximally happy. (Correct sad is better than glitched happy!)
        # Then we pick our arbitrary-ish gender, then we pick the latest if all
        # else failed and it's an unlabeled free-for-all.
        pet_state.mood_id.present? ? -1 : 1, # Prefer mood is labeled
        !pet_state.glitched? ? -1 : 1, # Prefer is not glitched
        pet_state.mood_id, # Prefer mood is happy, then sad, then sick
        gender == preferred_gender ? -1 : 1, # Prefer our "random" gender
        -pet_state.id, # Prefer newer pet states
      ]
    }.first
  end

  # Given a list of items, return how they look on this pet type.
  def appearances_for(item, ...)
    Item.appearances_for(item, self, ...)
  end

  def to_param
    "#{possibly_new_color.to_param}-#{possibly_new_species.to_param}"
  end

  def fully_labeled?
    num_missing_poses == 0
  end

  def num_poses
    all_poses = pet_states.map(&:pose)
    PetState::MAIN_POSES.count { |pose| all_poses.include? pose }
  end

  def num_missing_poses
    PetState::MAIN_POSES.count - num_poses
  end

  def num_unlabeled_states
    pet_states.count { |ps| ps.pose == "UNKNOWN" }
  end

  def reference
    PetType.where(species_id: species).basic.merge(Color.alphabetical).first
  end

  def self.find_by_param!(param)
    raise ActiveRecord::RecordNotFound unless param.include?("-")
    color_param, _, species_param = param.rpartition("-")
    where(
      color_id: Color.param_to_id(color_param),
      species_id: Species.param_to_id(species_param),
    ).first!
  end

  def self.basic_body_ids
    PetType.basic.distinct.pluck(:body_id)
  end

  def self.all_by_ids_or_children(ids, pet_states)
    pet_states_by_pet_type_id = {}
    pet_states.each do |pet_state|
      id = pet_state.pet_type_id
      ids << id
      pet_states_by_pet_type_id[id] ||= []
      pet_states_by_pet_type_id[id] << pet_state
    end
    find(ids).tap do |pet_types|
      pet_types.each do |pet_type|
        pet_states = pet_states_by_pet_type_id[pet_type.id]
        if pet_states
          pet_states.each do |pet_state|
            pet_state.pet_type = pet_type
          end
        end
      end
    end
  end
end

