class Pet < ApplicationRecord
  belongs_to :pet_type

  attr_reader :items, :pet_state, :alt_style

  def load!(timeout: nil)
    viewer_data = Neopets::CustomPets.fetch_viewer_data(name, timeout:)
    use_viewer_data(viewer_data)
  end

  def use_viewer_data(viewer_data)
    pet_data = viewer_data[:custom_pet]

    raise UnexpectedDataFormat unless pet_data[:species_id]
    raise UnexpectedDataFormat unless pet_data[:color_id]
    raise UnexpectedDataFormat unless pet_data[:body_id]

    @pet_state = Pet.pet_state_from_pet_data(pet_data)
    self.pet_type = @pet_state.pet_type

    begin
      pet_type.consider_pet_image(name)
    rescue => error
      Rails.logger.warn "Failed to load pet image: #{error.full_message}"
    end

    if pet_data[:alt_style]
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
      style: self.alt_style ? self.alt_style.id : nil,
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
    @pet_state.save! if @pet_state

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

  def self.pet_state_from_pet_data(pet_data)
    # First, set up the pet type.
    pet_type = PetType.find_or_initialize_by(
      species_id: pet_data[:species_id],
      color_id: pet_data[:color_id],
    )

    # Apply the pet's body ID to the pet type, unless it's wearing an alt
    # style, in which case ignore it, because it's the *alt style*'s body ID.
    # (This can theoretically cause a problem saving a new pet type when
    # there's an alt style too!)
    pet_type.body_id = pet_data[:body_id] unless pet_data[:alt_style]
    if pet_type.body_id.nil?
      raise UnexpectedDataFormat,
        "can't process alt style on first occurrence of pet type"
    end

    # Then, set up the biology assets.
    pet_state_biology = pet_data[:alt_style].present? ?
      pet_data[:original_biology] :
      pet_data[:biology_by_zone]
    body_id = pet_data[:body_id].to_i
    swf_assets = pet_state_biology.values.map do |biology_data|
      SwfAsset.from_biology_data(body_id, biology_data)
    end
    swf_asset_ids = swf_assets.map(&:remote_id).sort.join(",")

    # Finally, set up the pet state, and use these biology assets.
    pet_type.pet_states.find_or_initialize_by(swf_asset_ids:).tap do |pet_state|
      pet_state.swf_assets = swf_assets
    end
  end

  class UnexpectedDataFormat < RuntimeError;end
end

