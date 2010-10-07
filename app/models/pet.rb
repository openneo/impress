class Pet < ActiveRecord::Base
  GATEWAY_URL = 'http://www.neopets.com/amfphp/gateway.php'
  AMF_SERVICE_NAME = 'CustomPetService'
  PET_VIEWER_METHOD = 'getViewerData'
  PET_NOT_FOUND_REMOTE_ERROR = 'PHP: Unable to retrieve records from the database.'
  
  belongs_to :pet_type
  
  attr_reader :items
  
  def load!
    require 'ostruct'
    begin
      envelope = Pet.amf_service.fetch(PET_VIEWER_METHOD, name, nil)
    rescue RocketAMF::RemoteGateway::AMFError => e
      if e.message == PET_NOT_FOUND_REMOTE_ERROR
        raise PetNotFound, "Pet #{name.inspect} does not exist"
      end
      raise
    end
    contents = OpenStruct.new(envelope.messages[0].data.body)
    pet_data = OpenStruct.new(contents.custom_pet)
    self.pet_type = PetType.find_or_initialize_by_species_id_and_color_id(
        pet_data.species_id.to_i,
        pet_data.color_id.to_i
      )
    self.pet_type.body_id = pet_data.body_id
    @pet_state = self.pet_type.add_pet_state_from_biology! pet_data.biology_by_zone
    @items = Item.collection_from_pet_type_and_registries(self.pet_type,
      contents.object_info_registry, contents.object_asset_registry)
    true
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
end
