require 'rocketamf/remote_gateway'
require 'ostruct'

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
      viewer_data = fetch_viewer_data(options[:timeout])
      pet_data = viewer_data[:custom_pet]
      
      self.pet_type = PetType.find_or_initialize_by_species_id_and_color_id(
        pet_data[:species_id].to_i,
        pet_data[:color_id].to_i
      )
      self.pet_type.body_id = pet_data[:body_id]
      self.pet_type.origin_pet = self
      biology = pet_data[:biology_by_zone]
      biology[0] = nil # remove effects if present
      @pet_state = self.pet_type.add_pet_state_from_biology! biology
      @pet_state.label_by_pet(self, pet_data[:owner])
      @items = Item.collection_from_pet_type_and_registries(self.pet_type,
        viewer_data[:object_info_registry], viewer_data[:object_asset_registry],
        options[:item_scope])
    end

    true
  end
  
  def fetch_viewer_data(timeout=4)
    begin
      neopets_language_code = I18n.compatible_neopets_language_code_for(I18n.locale)
      envelope = PET_VIEWER.request([name, 0]).post(
        :timeout => timeout,
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
      raise DownloadError, e.message, e.backtrace
    end
    HashWithIndifferentAccess.new(envelope.messages[0].data.body)
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
      # Organize known items by ID
      items_by_id = {}
      @items.each { |i| items_by_id[i.id] = i }
      
      # Fetch registry data in parallel
      registries = Parallel.map(candidates.keys, :in_threads => 8) do |locale|
        viewer_data = I18n.with_locale(locale) { fetch_viewer_data }
        [locale, viewer_data[:object_info_registry]]
      end
      
      # Look up any newly applied items on this pet, just in case
      new_item_ids = []
      registries.each do |locale, registry|
        registry.each do |item_id, item_info|
          item_id = item_id.to_i
          new_item_ids << item_id unless items_by_id.has_key?(item_id)
        end
      end
      Item.includes(:translations).find(new_item_ids).each do |item|
        items_by_id[item.id] = item
      end
      
      # Apply translations, and figure out what items are currently being worn
      current_items = Set.new
      registries.each do |locale, registry|
        I18n.with_locale(locale) do
          registry.each do |item_id, item_info|
            item = items_by_id[item_id.to_i]
            item.origin_registry_info = item_info
            current_items << item
          end
        end
      end
      
      @items = current_items
      Item.transaction { @items.each { |i| i.save! if i.changed? } }
      
      previous_candidates = candidates
      candidates = item_translation_candidates
      
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
        item.save! if item.changed?
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

