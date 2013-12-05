class PetType < ActiveRecord::Base
  IMAGE_CPN_FORMAT = 'http://pets.neopets.com/cpn/%s/1/1.png';
  IMAGE_CP_LOCATION_REGEX = %r{^/cp/(.+?)/1/1\.png$};
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
  scope :single_standard_color, lambda { where(:color_id => Color.basic.first) }

  scope :nonstandard_colors, lambda { where(:color_id => Color.nonstandard) }
  
  scope :includes_child_translations,
    lambda { includes({:color => :translations, :species => :translations}) }

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

  def as_json(options={})
    if options[:for] == 'wardrobe'
      {
        :id => id,
        :body_id => body_id,
        :pet_states => pet_states.emotion_order.as_json
      }
    else
      {:image_hash => image_hash}
    end
  end

  def image_hash
    self['image_hash'] || basic_image_hash
  end

  def basic_image_hash
    I18n.with_locale(I18n.default_locale) do
      # Probably should move the basic hashes into the database someday.
      # Until then, access the hash using the English color/species names.
      
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
      match = new_url.match(IMAGE_CP_LOCATION_REGEX)
      if match
        self.image_hash = match[1]
        Rails.logger.info "Successfully loaded #{cpn_uri}, saved image hash #{match[1]}"
      else
        raise DownloadError, "CPN image pointed to #{new_url}, which does not match CP image format"
      end
    end
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

