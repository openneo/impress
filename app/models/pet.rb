require 'rocketamf/remote_gateway'

class Pet < ActiveRecord::Base
  GATEWAY_URL = 'http://www.neopets.com/amfphp/gateway.php'
  PET_VIEWER = RocketAMF::RemoteGateway.new(GATEWAY_URL).
    service('CustomPetService').action('getViewerData')
  PET_NOT_FOUND_REMOTE_ERROR = 'PHP: Unable to retrieve records from the database.'
  WARDROBE_PATH = '/wardrobe'

  belongs_to :pet_type

  attr_reader :items, :pet_state
  attr_accessor :contributor

  scope :with_pet_type_color_ids, lambda { |color_ids|
    joins(:pet_type).where(PetType.arel_table[:id].in(color_ids))
  }

  def load!(options={})
    options[:item_scope] ||= Item.scoped
    options[:locale] ||= I18n.default_locale
    
    I18n.with_locale(options[:locale]) do
      require 'ostruct'
      begin
        neopets_language_code = I18n.compatible_neopets_language_code_for(options[:locale])
        envelope = PET_VIEWER.request([name, 0]).post(
          :timeout => 2,
          :headers => {
            'Cookie' => "lang=#{neopets_language_code}"
          }
        )
      rescue RocketAMF::RemoteGateway::AMFError => e
        if e.message == PET_NOT_FOUND_REMOTE_ERROR
          raise PetNotFound, "Pet #{name.inspect} does not exist"
        end
        raise DownloadError, e.message
      rescue RocketAMF::RemoteGateway::ConnectionError => e
        raise DownloadError, e.message
      end
      contents = OpenStruct.new(envelope.messages[0].data.body)
      pet_data = OpenStruct.new(contents.custom_pet)
      
      # in case this is running in a thread, explicitly grab an ActiveRecord
      # connection, to avoid connection conflicts
      Pet.connection_pool.with_connection do
        self.pet_type = PetType.find_or_initialize_by_species_id_and_color_id(
            pet_data.species_id.to_i,
            pet_data.color_id.to_i
          )
        self.pet_type.body_id = pet_data.body_id
        self.pet_type.origin_pet = self
        biology = pet_data.biology_by_zone
        biology[0] = nil # remove effects if present
        @pet_state = self.pet_type.add_pet_state_from_biology! biology
        @pet_state.label_by_pet(self, pet_data.owner)
        @items = Item.collection_from_pet_type_and_registries(self.pet_type,
          contents.object_info_registry, contents.object_asset_registry,
          options[:item_scope])
      end
    end

    true
  end

  def wardrobe_query
    {
      :name => self.name,
      :color => self.pet_type.color.id,
      :species => self.pet_type.species.id,
      :state => self.pet_state.id,
      :objects => self.items.map(&:id)
    }.to_query
  end

  def contributables
    contributables = [pet_type, @pet_state]
    items.each do |item|
      contributables << item
      contributables += item.pending_swf_assets
    end
    contributables
  end
  
  def item_translation_candidates
    {}.tap do |candidates|
      if @items
        @items.each do |item|
          item.needed_translations.each do |locale|
            candidates[locale] ||= []
            candidates[locale] << item
          end
        end
      end
    end
  end
  
  def translate_items
    candidates = self.item_translation_candidates
    
    until candidates.empty?
      last_pet_loaded = nil
      reloaded_pets = Parallel.map(candidates.keys, :in_threads => 8) do |locale|
        Rails.logger.info "Reloading #{name} in #{locale}"
        reloaded_pet = Pet.load(name, :item_scope => Item.includes(:translations),
                                      :locale => locale)
        Pet.connection_pool.with_connection { reloaded_pet.save! }
        last_pet_loaded = reloaded_pet
      end
      previous_candidates = candidates
      candidates = last_pet_loaded.item_translation_candidates
      
      if previous_candidates == candidates
        # This condition should never happen if Neopets responds with correct
        # data, but, if Neopets somehow responds with incorrect data, this
        # condition could throw us into an infinite loop if uncaught. Better
        # safe than sorry when working with external services.
        raise "No change when reloading #{name} for #{candidates}"
      end
    end
  end

  before_validation do
    pet_type.save!
    if @pet_state
      @pet_state.save!
      @pet_state.handle_assets!
    end
    
    if @items
      @items.each do |item|
        item.save!
        item.handle_assets!
      end
    end
  end

  def self.load(name, options={})
    pet = Pet.find_or_initialize_by_name(name)
    pet.load!(options)
    pet
  end

  class PetNotFound < Exception;end
  class DownloadError < Exception;end
end

