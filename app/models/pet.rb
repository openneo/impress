class Pet < ActiveRecord::Base
  GATEWAY_URL = 'http://www.neopets.com/amfphp/gateway.php'
  AMF_SERVICE_NAME = 'CustomPetService'
  PET_VIEWER_METHOD = 'getViewerData'
  PET_NOT_FOUND_REMOTE_ERROR = 'PHP: Unable to retrieve records from the database.'
  WARDROBE_PATH = '/wardrobe'

  belongs_to :pet_type

  attr_reader :items, :pet_state
  attr_accessor :contributor

  scope :with_pet_type_color_ids, lambda { |color_ids|
    joins(:pet_type).where(PetType.arel_table[:id].in(color_ids))
  }

  def load!
    require 'ostruct'
    begin
      envelope = Pet.amf_service.fetch(PET_VIEWER_METHOD, name, nil)
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
    self.pet_type = PetType.find_or_initialize_by_species_id_and_color_id(
        pet_data.species_id.to_i,
        pet_data.color_id.to_i
      )
    self.pet_type.body_id = pet_data.body_id
    self.pet_type.origin_pet = self
    biology = pet_data.biology_by_zone
    biology[0] = nil # remove effects if present
    @pet_state = self.pet_type.add_pet_state_from_biology! biology
    @items = Item.collection_from_pet_type_and_registries(self.pet_type,
      contents.object_info_registry, contents.object_asset_registry)
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

  before_validation do
    pet_type.save!
    @pet_state.save! if @pet_state
    if @items
      @items.each do |item|
        item.handle_assets!
        item.save!
      end
    end
  end

  def self.load(name)
    pet = Pet.find_or_initialize_by_name(name)
    pet.load!
    pet
  end

  private

  def self.amf_service
    @amf_service ||= gateway.service AMF_SERVICE_NAME
  end

  def self.gateway
    unless @gateway
      require 'rocketamf/remote_gateway'
      @gateway = RocketAMF::RemoteGateway.new(GATEWAY_URL)
    end
    @gateway
  end

  class PetNotFound < Exception;end
  class DownloadError < Exception;end
end

