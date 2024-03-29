class PetType < ApplicationRecord
  IMAGE_CPN_FORMAT = 'https://pets.neopets.com/cpn/%s/1/1.png';
  IMAGE_CP_LOCATION_REGEX = %r{^/cp/(.+?)/[0-9]+/[0-9]+\.png$};
  IMAGE_CPN_ACCEPTABLE_NAME = /^[a-z0-9_]+$/

  belongs_to :species
  belongs_to :color
  has_one :contribution, :as => :contributed, :inverse_of => :contributed
  has_many :pet_states
  has_many :pets

  attr_writer :origin_pet

  BasicHashes = YAML::load_file(Rails.root.join('config', 'basic_type_hashes.yml'))

  # Returns all pet types of a single standard color. The caller shouldn't care
  # which, though, in this implemention, it's always Blue. Don't depend on that.
  scope :single_standard_color, -> { where(:color_id => Color.basic.first) }

  scope :nonstandard_colors, -> { where(:color_id => Color.nonstandard) }
  
  scope :includes_child_translations,
    -> { includes({:color => :translations, :species => :translations}) }
  
  scope :matching_name, ->(color_name, species_name, locale = I18n.locale) {
    color = Color.matching_name(color_name, locale).first!
    species = Species.matching_name(species_name, locale).first!
    where(color_id: color.id, species_id: species.id)
  }

  def self.special_color_or_basic(special_color)
    color_ids = special_color ? [special_color.id] : Color.basic.select([:id]).map(&:id)
    where(color_id: color_ids)
  end
  
  def self.standard_body_ids
    [].tap do |body_ids|
      # TODO: the nil hack is lame :P
      special_color_or_basic(nil).group_by(&:species_id).each do |species_id, pet_types|
        body_ids.concat(pet_types.map(&:body_id))
      end
    end
  end

  def self.random_basic_per_species(species_ids)
    random_pet_types = []
    # TODO: omg so lame :P
    standards = special_color_or_basic(nil).group_by(&:species_id)
    species_ids.each do |species_id|
      pet_types = standards[species_id]
      random_pet_types << pet_types[rand(pet_types.size)] if pet_types
    end
    random_pet_types
  end

  def self.get_hash_from_cp_path(path)
    match = path.match(IMAGE_CP_LOCATION_REGEX)
    match ? match[1] : nil
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
    basic_image_hash || self['image_hash'] || fallback_image_hash
  end

  def fallback_image_hash
    I18n.with_locale(I18n.default_locale) do
      if species && color && BasicHashes[species.name] && BasicHashes[species.name][color.name]
        BasicHashes[species.name][color.name]
      else
        return 'deadbeef'
      end
    end
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

  def needed_items
    # If I need this item on a pet type, that means that we've already seen it
    # and it's body-specific. So, there's a body-specific asset for the item,
    # but no asset that fits this pet type.
    i = Item.arel_table
    psa = ParentSwfAssetRelationship.arel_table
    sa = SwfAsset.arel_table

    Item.where('(' + ParentSwfAssetRelationship.select('count(DISTINCT body_id)').joins(:swf_asset).
               where(
                 psa[:parent_id].eq(i[:id]).and(
                 psa[:parent_type].eq('Item').and(
                 sa[:body_id].not_eq(self.body_id)))
               ).to_sql + ') > 1').
         where(ParentSwfAssetRelationship.joins(:swf_asset).where(
                 psa[:parent_id].eq(i[:id]).and(
                 psa[:parent_type].eq('Item').and(
                 sa[:body_id].in([self.body_id, 0])))
               ).exists.not)
  end

  def add_pet_state_from_biology!(biology)
    pet_state = PetState.from_pet_type_and_biology_info(self, biology)
    pet_state
  end

  before_save do
    if @origin_pet && @origin_pet.name =~ IMAGE_CPN_ACCEPTABLE_NAME
      cpn_uri = URI.parse sprintf(IMAGE_CPN_FORMAT, CGI.escape(@origin_pet.name));
      begin
        res = Net::HTTP.get_response(cpn_uri)
      rescue Exception => e
        raise DownloadError, e.message
      end
      unless res.is_a? Net::HTTPFound
        begin
          res.error!
        rescue Exception => e
          raise DownloadError, "Error loading CPN image at #{cpn_uri}: #{e.message}"
        else
          raise DownloadError, "Error loading CPN image at #{cpn_uri}. Response: #{res.inspect}"
        end
      end
      new_url = res['location']
      new_image_hash = PetType.get_hash_from_cp_path(new_url)
      if new_image_hash
        self.image_hash = new_image_hash
        Rails.logger.info "Successfully loaded #{cpn_uri}, saved image hash #{new_image_hash}"
      else
        raise DownloadError, "CPN image pointed to #{new_url}, which does not match CP image format"
      end
    end
  end

  def canonical_pet_state
    # For consistency (randomness is always scary!), we use the PetType ID to
    # determine which gender to prefer. That way, it'll be stable, but we'll
    # still get the *vibes* of uniform randomness.
    preferred_gender = id % 2 == 0 ? :fem : :masc

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
        pet_state.mood_id.present? ? -1 : 1, # Prefer mood is labeled
        pet_state.mood_id, # Prefer mood is happy, then sad, then sick
        gender == preferred_gender ? -1 : 1, # Prefer our "random" gender
        -pet_state.id, # Prefer newer pet states
        !pet_state.glitched? ? -1 : 1, # Prefer is not glitched
      ]
    }.first
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

  class DownloadError < Exception;end
end

