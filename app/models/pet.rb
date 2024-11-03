class Pet < ApplicationRecord
  belongs_to :pet_type

  attr_reader :items, :pet_state, :alt_style

  def load!(timeout: nil)
    viewer_data_hash = Neopets::CustomPets.fetch_viewer_data(name, timeout:)
    use_viewer_data(ViewerData.new(viewer_data_hash))
  end

  def use_viewer_data(viewer_data)
    self.pet_type = viewer_data.pet_type
    @pet_state = viewer_data.pet_state
    @alt_style = viewer_data.alt_style
    @items = viewer_data.items
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

  class UnexpectedDataFormat < RuntimeError;end

  # A representation of a Neopets::CustomPets viewer data response, translated
  # to DTI's database models!
  class ViewerData
    def initialize(viewer_data_hash)
      @custom_pet = viewer_data_hash[:custom_pet]
      @object_info_registry = viewer_data_hash[:object_info_registry]
      @object_asset_registry = viewer_data_hash[:object_asset_registry]
    end

    def pet_type
      @pet_type ||= begin
        raise UnexpectedDataFormat unless @custom_pet[:species_id]
        raise UnexpectedDataFormat unless @custom_pet[:color_id]
        raise UnexpectedDataFormat unless @custom_pet[:body_id]

        @custom_pet => {species_id:, color_id:}
        PetType.find_or_initialize_by(species_id:, color_id:).tap do |pet_type|
          # Apply the pet's body ID to the pet type, unless it's wearing an alt
          # style, in which case ignore it, because it's the *alt style*'s body ID.
          # (This can theoretically cause a problem saving a new pet type when
          # there's an alt style too!)
          pet_type.body_id = @custom_pet[:body_id] unless @custom_pet[:alt_style]
          if pet_type.body_id.nil?
            raise UnexpectedDataFormat,
              "can't process alt style on first occurrence of pet type"
          end

          # Try using this pet for the pet type's thumbnail, but don't worry
          # if it fails.
          begin
            pet_type.consider_pet_image(@custom_pet[:name])
          rescue => error
            Rails.logger.warn "Failed to load pet image: #{error.full_message}"
          end
        end
      end
    end

    def pet_state
      @pet_state ||= begin
        # Choose the right biology, depending on if there's an alt style.
        pet_state_biology = @custom_pet[:alt_style].present? ?
          @custom_pet[:original_biology] :
          @custom_pet[:biology_by_zone]
        raise UnexpectedDataFormat if pet_state_biology.empty?

        # Then, set up the biology assets.
        body_id = @custom_pet[:body_id].to_i
        swf_assets = pet_state_biology.values.map do |biology_data|
          SwfAsset.from_biology_data(body_id, biology_data)
        end
        swf_asset_ids = swf_assets.map(&:remote_id).sort.join(",")

        # Then, set up the pet state, using these biology assets.
        pet_type.pet_states.find_or_initialize_by(swf_asset_ids:).tap do |pet_state|
          pet_state.swf_assets = swf_assets
        end
      end
    end

    def alt_style
      @alt_style ||= begin
        return nil unless @custom_pet[:alt_style]

        raise UnexpectedDataFormat unless @custom_pet[:alt_color]
        raise UnexpectedDataFormat if @custom_pet[:biology_by_zone].empty?

        id = @custom_pet[:alt_style].to_i
        AltStyle.find_or_initialize_by(id:).tap do |alt_style|
          alt_style.assign_attributes(
            color_id: @custom_pet[:alt_color].to_i,
            species_id: @custom_pet[:species_id].to_i,
            body_id: @custom_pet[:body_id].to_i,
            biology: @custom_pet[:biology_by_zone],
          )
        end
      end
    end

    def items
      @items ||= Item.collection_from_pet_type_and_registries(
        pet_type, @object_info_registry, @object_asset_registry
      )
    end
  end
end

