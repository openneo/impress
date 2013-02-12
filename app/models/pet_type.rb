class PetType < ActiveRecord::Base
  IMAGE_CPN_FORMAT = 'http://pets.neopets.com/cpn/%s/1/1.png';
  IMAGE_CP_LOCATION_REGEX = %r{^/cp/(.+?)/1/1\.png$};
  IMAGE_CPN_ACCEPTABLE_NAME = /^[a-z0-9_]+$/

  belongs_to :species
  belongs_to :color
  has_one :contribution, :as => :contributed
  has_many :pet_states
  has_many :pets

  attr_writer :origin_pet

  BasicHashes = YAML::load_file(Rails.root.join('config', 'basic_type_hashes.yml'))

  # Returns all pet types of a single standard color. The caller shouldn't care
  # which, though, in this implemention, it's always Blue. Don't depend on that.
  scope :single_standard_color, lambda { where(:color_id => Color.standard.first) }

  scope :nonstandard_colors, lambda { where(:color_id => Color.nonstandard) }
  
  scope :includes_child_translations,
    lambda { includes({:color => :translations, :species => :translations}) }
  
  def self.standard_pet_types_by_species_id
    PetType.where(:color_id => Color.basic).includes_child_translations.
      group_by(&:species_id)
  end
  
  def self.standard_body_ids
    [].tap do |body_ids|
      standard_pet_types_by_species_id.each do |species_id, pet_types|
        body_ids.concat(pet_types.map(&:body_id))
      end
    end
  end

  def self.random_basic_per_species(species_ids)
    random_pet_types = []
    standards = self.standard_pet_types_by_species_id
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
      
      unless BasicHashes[species.name] && BasicHashes[species.name][color.name]
        # TODO: use rainbow pool? some external service?
        return 'deadbeef'
      end
      
      BasicHashes[species.name][color.name]
    end
  end

  def human_name
    self.color.human_name + ' ' + self.species.human_name
  end

  def needed_items
    items = Item.arel_table
    species_matchers = [
      "#{species_id},%",
      "%,#{species_id},%",
      "%,#{species_id}"
    ]
    species_condition = nil
    species_matchers.each do |matcher|
      condition = items[:species_support_ids].matches(matcher)
      if species_condition
        species_condition = species_condition.or(condition)
      else
        species_condition = condition
      end
    end
    unneeded_item_ids = Item.select(items[:id]).
      joins(:parent_swf_asset_relationships => :swf_asset).
      where(SwfAsset.arel_table[:body_id].in([0, self.body_id])).map(&:id)
    Item.where(items[:id].not_in(unneeded_item_ids)).
      where(species_condition)
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

