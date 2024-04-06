require 'rocketamf_extensions/remote_gateway'
require 'ostruct'

class Pet < ApplicationRecord
  NEOPETS_URL_ORIGIN = ENV['NEOPETS_URL_ORIGIN'] || 'https://www.neopets.com'
  GATEWAY_URL = NEOPETS_URL_ORIGIN + '/amfphp/gateway.php'
  PET_VIEWER = RocketAMFExtensions::RemoteGateway.new(GATEWAY_URL).
    service('CustomPetService').action('getViewerData')
  PET_NOT_FOUND_REMOTE_ERROR = 'PHP: Unable to retrieve records from the database.'
  WARDROBE_PATH = '/wardrobe'

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

    new_image_hash = Pet.fetch_image_hash(self.name)
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

  def self.from_viewer_data(viewer_data)
    pet = Pet.find_or_initialize_by(name: viewer_data[:custom_pet][:name])
    pet.use_viewer_data(viewer_data)
    pet
  end

  # NOTE: Ideally pet requests shouldn't take this long, but Neopets can be
  # slow sometimes! Since we're on the Falcon server, long timeouts shouldn't
  # slow down the rest of the request queue, like it used to be in the past.
  def self.fetch_viewer_data(name, timeout: 10)
    begin
      envelope = PET_VIEWER.request([name, 0]).post(timeout: timeout)
    rescue RocketAMFExtensions::RemoteGateway::AMFError => e
      if e.message == PET_NOT_FOUND_REMOTE_ERROR
        raise PetNotFound, "Pet #{name.inspect} does not exist"
      end
      raise DownloadError, e.message
    rescue RocketAMFExtensions::RemoteGateway::ConnectionError => e
      raise DownloadError, e.message, e.backtrace
    end
    HashWithIndifferentAccess.new(envelope.messages[0].data.body)
  end

  # Given a pet's name, load its image hash, for use in `pets.neopets.com`
  # image URLs. (This corresponds to its current biology and items.)
  IMAGE_CPN_FORMAT = 'https://pets.neopets.com/cpn/%s/1/1.png';
  IMAGE_CP_LOCATION_REGEX = %r{^/cp/(.+?)/[0-9]+/[0-9]+\.png$};
  IMAGE_CPN_ACCEPTABLE_NAME = /^[A-Za-z0-9_]+$/
  def self.fetch_image_hash(name)
    return nil unless name.match?(IMAGE_CPN_ACCEPTABLE_NAME)

    cpn_uri = URI.parse sprintf(IMAGE_CPN_FORMAT, CGI.escape(name))
    begin
      res = Net::HTTP.get_response(cpn_uri, {
        'User-Agent' => Rails.configuration.user_agent_for_neopets
      })
    rescue Exception => e
      raise DownloadError, e.message
    end
    unless res.is_a? Net::HTTPFound
      begin
        res.error!
      rescue Exception => e
        Rails.logger.warn "Error loading CPN image at #{cpn_uri}: #{e.message}"
        return
      else
        Rails.logger.warn "Error loading CPN image at #{cpn_uri}. Response: #{res.inspect}"
        return
      end
    end
    new_url = res['location']
    new_image_hash = get_hash_from_cp_path(new_url)
    if new_image_hash
      Rails.logger.info "Successfully loaded #{cpn_uri}, with image hash #{new_image_hash}"
      new_image_hash
    else
      Rails.logger.warn "CPN image pointed to #{new_url}, which does not match CP image format"
    end
  end

  def self.get_hash_from_cp_path(path)
    match = path.match(IMAGE_CP_LOCATION_REGEX)
    match ? match[1] : nil
  end

  class PetNotFound < RuntimeError;end
  class DownloadError < RuntimeError;end
  class UnexpectedDataFormat < RuntimeError;end
end

