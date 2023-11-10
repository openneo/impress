require 'rocketamf/remote_gateway'
require 'ostruct'

class Pet < ApplicationRecord
  NEOPETS_URL_ORIGIN = ENV['NEOPETS_URL_ORIGIN'] || 'https://www.neopets.com'
  GATEWAY_URL = NEOPETS_URL_ORIGIN + '/amfphp/gateway.php'
  PET_VIEWER = RocketAMF::RemoteGateway.new(GATEWAY_URL).
    service('CustomPetService').action('getViewerData')
  PET_NOT_FOUND_REMOTE_ERROR = 'PHP: Unable to retrieve records from the database.'
  WARDROBE_PATH = '/wardrobe'

  belongs_to :pet_type

  attr_reader :items, :pet_state
  attr_accessor :contributor

  scope :with_pet_type_color_ids, ->(color_ids) {
    joins(:pet_type).where(PetType.arel_table[:id].in(color_ids))
  }

  def load!(options={})
    options[:locale] ||= I18n.default_locale
    I18n.with_locale(options.delete(:locale)) do
      use_viewer_data(fetch_viewer_data(options.delete(:timeout)), options)
    end
    true
  end

  def use_viewer_data(viewer_data, options={})
    options[:item_scope] ||= Item.all

    pet_data = viewer_data[:custom_pet]

    self.pet_type = PetType.find_or_initialize_by(
      species_id: pet_data[:species_id].to_i,
      color_id: pet_data[:color_id].to_i
    )
    self.pet_type.body_id = pet_data[:body_id]
    self.pet_type.origin_pet = self
    biology = pet_data[:biology_by_zone]
    biology[0] = nil # remove effects if present
    @pet_state = self.pet_type.add_pet_state_from_biology! biology
    @items = Item.collection_from_pet_type_and_registries(self.pet_type,
      viewer_data[:object_info_registry], viewer_data[:object_asset_registry],
      options[:item_scope])
  end
  
  def fetch_viewer_data(timeout=4, locale=nil)
    locale ||= I18n.default_locale
    begin
      neopets_language_code = I18n.compatible_neopets_language_code_for(locale)
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
    pet = Pet.find_or_initialize_by(name: name)
    pet.load!(options)
    pet
  end

  def self.from_viewer_data(viewer_data, options={})
    pet = Pet.find_or_initialize_by(name: viewer_data[:custom_pet][:name])
    pet.use_viewer_data(viewer_data, options)
    pet
  end

  class PetNotFound < Exception;end
  class DownloadError < Exception;end
end

