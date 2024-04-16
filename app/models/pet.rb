require 'rocketamf_extensions/remote_gateway'
require 'ostruct'

class Pet < ApplicationRecord
  NEOPETS_URL_ORIGIN = ENV['NEOPETS_URL_ORIGIN'] || 'https://www.neopets.com'
  GATEWAY_URL = NEOPETS_URL_ORIGIN + '/amfphp/gateway.php'
  GATEWAY = RocketAMFExtensions::RemoteGateway.new(GATEWAY_URL)
  CUSTOM_PET_SERVICE = GATEWAY.service('CustomPetService')
  PET_SERVICE = GATEWAY.service('PetService')

  belongs_to :pet_type

  attr_reader :items, :pet_state, :alt_style

  scope :with_pet_type_color_ids, ->(color_ids) {
    joins(:pet_type).where(PetType.arel_table[:id].in(color_ids))
  }

  def load!(timeout: nil)
    viewer_data = self.class.fetch_viewer_data(name, timeout:)
    use_viewer_data(viewer_data)
  end

  def use_viewer_data(viewer_data)
    pet_data = viewer_data[:custom_pet]

    raise UnexpectedDataFormat unless pet_data[:species_id]
    raise UnexpectedDataFormat unless pet_data[:color_id]
    raise UnexpectedDataFormat unless pet_data[:body_id]

    has_alt_style = pet_data[:alt_style].present?

    self.pet_type = PetType.find_or_initialize_by(
      species_id: pet_data[:species_id].to_i,
      color_id: pet_data[:color_id].to_i
    )

    begin
      new_image_hash = Pet.fetch_image_hash(self.name)
    rescue => error
      Rails.logger.warn "Failed to load image hash: #{error.full_message}"
    end
    self.pet_type.image_hash = new_image_hash if new_image_hash.present?

    # With an alt style, `body_id` in the biology data refers to the body ID of
    # the *alt* style, not the usual pet type. (We have `original_biology` for
    # *some* of the pet type's situation, but not it's body ID!)
    #
    # So, in the alt style case, don't update `body_id` - but if this is our
    # first time seeing this pet type and it doesn't *have* a `body_id` yet,
    # let's not be creating it without one. We'll need to model it without the
    # alt style first. (I don't bother with a clear error message though 😅)
    self.pet_type.body_id = pet_data[:body_id] unless has_alt_style
    if self.pet_type.body_id.nil?
      raise UnexpectedDataFormat,
        "can't process alt style on first occurrence of pet type"
    end

    pet_state_biology = has_alt_style ? pet_data[:original_biology] :
      pet_data[:biology_by_zone]
    raise UnexpectedDataFormat if pet_state_biology.empty?
    pet_state_biology[0] = nil # remove effects if present
    @pet_state = self.pet_type.add_pet_state_from_biology! pet_state_biology

    if has_alt_style
      raise UnexpectedDataFormat unless pet_data[:alt_color]
      raise UnexpectedDataFormat if pet_data[:biology_by_zone].empty?

      @alt_style = AltStyle.find_or_initialize_by(id: pet_data[:alt_style].to_i)
      @alt_style.assign_attributes(
        color_id: pet_data[:alt_color].to_i,
        species_id: pet_data[:species_id].to_i,
        body_id: pet_data[:body_id].to_i,
        biology: pet_data[:biology_by_zone],
      )
    end

    @items = Item.collection_from_pet_type_and_registries(self.pet_type,
      viewer_data[:object_info_registry], viewer_data[:object_asset_registry])
  end

  def wardrobe_query
    {
      name: self.name,
      color: self.pet_type.color_id,
      species: self.pet_type.species_id,
      pose: self.pet_state.pose,
      state: self.pet_state.id,
      objects: self.items.map(&:id),
    }.to_query
  end

  def contributables
    contributables = [pet_type, @pet_state, @alt_style].filter(&:present?)
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

    if @alt_style
      @alt_style.save!
    end
  end

  def self.load(name, **options)
    pet = Pet.find_or_initialize_by(name: name)
    pet.load!(**options)
    pet
  end

  # NOTE: Ideally pet requests shouldn't take this long, but Neopets can be
  # slow sometimes! Since we're on the Falcon server, long timeouts shouldn't
  # slow down the rest of the request queue, like it used to be in the past.
  def self.fetch_viewer_data(name, timeout: 10)
    request = CUSTOM_PET_SERVICE.action('getViewerData').request([name])
    send_amfphp_request(request).tap do |data|
      if data[:custom_pet][:name].blank?
        raise PetNotFound, "Pet #{name.inspect} does not exist"
      end
    end
  end

  def self.fetch_metadata(name, timeout: 10)
    request = PET_SERVICE.action('getPet').request([name])
    send_amfphp_request(request).tap do |data|
      if data[:name].blank?
        raise PetNotFound, "Pet #{name.inspect} does not exist"
      end
    end
  end

  # Given a pet's name, load its image hash, for use in `pets.neopets.com`
  # image URLs. (This corresponds to its current biology and items.)
  def self.fetch_image_hash(name, timeout: 10)
    metadata = fetch_metadata(name, timeout:)
    metadata[:hash]
  end

  class PetNotFound < RuntimeError;end
  class DownloadError < RuntimeError;end
  class UnexpectedDataFormat < RuntimeError;end

  private

  # Send an AMFPHP request, re-raising errors as `Pet::DownloadError`.
  # Return the response body as a `HashWithIndifferentAccess`.
  def self.send_amfphp_request(request, timeout: 10)
    begin
      response = request.post(timeout: timeout, headers: {
        "User-Agent" => Rails.configuration.user_agent_for_neopets,
      })
    rescue RocketAMFExtensions::RemoteGateway::AMFError => e
      raise DownloadError, e.message
    rescue RocketAMFExtensions::RemoteGateway::ConnectionError => e
      raise DownloadError, e.message, e.backtrace
    end

    HashWithIndifferentAccess.new(response.messages[0].data.body)
  end
end

