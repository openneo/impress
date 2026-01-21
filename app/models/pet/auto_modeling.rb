# Pet::AutoModeling provides utilities for automatically modeling items on pet
# bodies using the NC Mall preview API. This allows us to fetch appearance data
# for items without needing a real pet of that type.
#
# The workflow:
# 1. Generate a combined "SCI" (Species/Color Image hash) using NC Mall's
#    getPetData endpoint, which combines a pet type with items.
# 2. Fetch the viewer data for that combined SCI using the CustomPets API.
# 3. Process the viewer data to create SwfAsset records.
module Pet::AutoModeling
  extend self

  # Model an item on a specific body ID. This fetches the appearance data from
  # Neopets and creates/updates the SwfAsset records.
  #
  # @param item [Item] The item to model
  # @param body_id [Integer] The body ID to model on
  # @return [Symbol] Result status:
  #   - :modeled - Successfully created SwfAsset records
  #   - :not_compatible - Item is explicitly not compatible with this body
  # @raise [NoPetTypeForBody] If no PetType exists for this body_id
  # @raise [Neopets::NCMall::ResponseNotOK] On HTTP errors (transient for 5xx)
  # @raise [Neopets::NCMall::UnexpectedResponseFormat] On invalid response
  # @raise [Neopets::CustomPets::DownloadError] On AMF protocol errors
  def model_item_on_body(item, body_id)
    # Find a pet type with this body ID to use as a base
    pet_type = PetType.find_by(body_id: body_id)
    raise NoPetTypeForBody.new(body_id) if pet_type.nil?

    # Fetch the viewer data for this item on this pet type
    new_image_hash = Neopets::NCMall.fetch_pet_data_sci(pet_type.image_hash, [item.id])
    viewer_data = Neopets::CustomPets.fetch_viewer_data("@#{new_image_hash}")

    # If the item wasn't in the response, it's not compatible.
    object_info = viewer_data[:object_info_registry]&.to_h&.[](item.id.to_s)
    return :not_compatible if object_info.nil?

    # Process the modeling data using the existing infrastructure
    snapshot = Pet::ModelingSnapshot.new(viewer_data)

    # Save the pet type (may update image hash, etc.)
    snapshot.pet_type.save!

    # Get the items from the snapshot and process them
    modeled_items = snapshot.items
    modeled_item = modeled_items.find { |i| i.id == item.id }

    if modeled_item
      modeled_item.save!
      modeled_item.handle_assets!
    end

    :modeled
  end

  class NoPetTypeForBody < StandardError
    attr_reader :body_id
    def initialize(body_id)
      @body_id = body_id
      super("No PetType found for body_id=#{body_id}")
    end
  end
end
