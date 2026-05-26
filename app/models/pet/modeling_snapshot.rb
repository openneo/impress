# A representation of a Neopets::CustomPets viewer data response, translated
# to DTI's database models!
class Pet::ModelingSnapshot
  def initialize(viewer_data_hash)
    @custom_pet = viewer_data_hash[:custom_pet]
    @object_info_registry = viewer_data_hash[:object_info_registry]
    @object_asset_registry = viewer_data_hash[:object_asset_registry]
  end

  def pet_type
    @pet_type ||= begin
      raise Pet::UnexpectedDataFormat unless @custom_pet[:species_id]
      raise Pet::UnexpectedDataFormat unless @custom_pet[:color_id]
      raise Pet::UnexpectedDataFormat unless @custom_pet[:body_id]

      @custom_pet => {species_id:, color_id:}
      PetType.find_or_initialize_by(species_id:, color_id:).tap do |pet_type|
        # Apply the pet's body ID to the pet type, unless it's wearing an alt
        # style, in which case ignore it, because it's the *alt style*'s body ID.
        # (This can theoretically cause a problem saving a new pet type when
        # there's an alt style too!)
        pet_type.body_id = @custom_pet[:body_id] unless @custom_pet[:alt_style]
        if pet_type.body_id.nil?
          raise Pet::UnexpectedDataFormat,
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
    return @pet_state if defined?(@pet_state)
    @pet_state = if biology_assets
      swf_asset_ids = biology_assets.map(&:remote_id)
      pet_type.pet_states.find_or_initialize_by(swf_asset_ids:).tap do |pet_state|
        pet_state.swf_assets = biology_assets
      end
    end
  end

  def alt_style
    @alt_style ||= begin
      return nil unless @custom_pet[:alt_style]
      raise Pet::UnexpectedDataFormat unless @custom_pet[:alt_color]

      id = @custom_pet[:alt_style].to_i
      AltStyle.find_or_initialize_by(id:).tap do |alt_style|
        pet_name = @custom_pet[:name]

        # Capture old asset IDs before assignment
        old_asset_ids = alt_style.swf_assets.map(&:remote_id).sort

        # Assign new attributes and assets
        new_asset_ids = alt_style_assets.map(&:remote_id).sort
        alt_style.assign_attributes(
          color_id: @custom_pet[:alt_color].to_i,
          species_id: @custom_pet[:species_id].to_i,
          body_id: @custom_pet[:body_id].to_i,
          swf_assets: alt_style_assets,
        )

        # Log the modeling event using Rails' change tracking
        if alt_style.new_record?
          Rails.logger.info "[Alt Style Modeling] Created alt style " \
            "ID=#{id} for pet=#{pet_name}: " \
            "species_id=#{alt_style.species_id}, " \
            "color_id=#{alt_style.color_id}, " \
            "body_id=#{alt_style.body_id}, " \
            "asset_ids=#{new_asset_ids.inspect}"
        elsif alt_style.changes.any? || old_asset_ids != new_asset_ids
          changes = []
          changes << "species_id: #{alt_style.species_id_was} -> #{alt_style.species_id}" if alt_style.species_id_changed?
          changes << "color_id: #{alt_style.color_id_was} -> #{alt_style.color_id}" if alt_style.color_id_changed?
          changes << "body_id: #{alt_style.body_id_was} -> #{alt_style.body_id}" if alt_style.body_id_changed?
          changes << "asset_ids: #{old_asset_ids.inspect} -> #{new_asset_ids.inspect}" if old_asset_ids != new_asset_ids

          Rails.logger.warn "[Alt Style Modeling] Updated alt style " \
            "ID=#{id} for pet=#{pet_name}. " \
            "CHANGED: #{changes.join(', ')}"
        else
          Rails.logger.info "[Alt Style Modeling] Loaded alt style " \
            "ID=#{id} for pet=#{pet_name} (no changes)"
        end
      end
    end
  end

  def items
    @items ||= Item.collection_from_pet_type_and_registries(
      pet_type, @object_info_registry, @object_asset_registry
    )
  end

  private

  def biology_assets
    return @biology_assets if defined?(@biology_assets)
    @biology_assets = if @custom_pet[:alt_style].present?
      # The sci (@) format omits original_biology for alt-style pets; that's
      # expected, so return nil rather than raising.
      biology = @custom_pet[:original_biology]
      assets_from_biology(biology) if biology.present?
    else
      assets_from_biology(@custom_pet[:biology_by_zone])
    end
  end

  def item_assets_for(item_id)
    all_infos = @object_asset_registry.values
    infos = all_infos.select { |a| a[:obj_info_id].to_i == item_id.to_i }
    infos.map do |asset_data|
      remote_id = asset_data[:asset_id].to_i
      SwfAsset.find_or_initialize_by(type: "object", remote_id:).tap do |swf_asset|
        swf_asset.origin_pet_type = pet_type
        swf_asset.origin_object_data = asset_data
      end
    end
  end

  def alt_style_assets
    raise Pet::UnexpectedDataFormat if @custom_pet[:biology_by_zone].empty?
    assets_from_biology(@custom_pet[:biology_by_zone])
  end

  def assets_from_biology(biology)
    raise Pet::UnexpectedDataFormat if biology.empty?
    body_id = @custom_pet[:body_id].to_i
    biology.values.map { |b| SwfAsset.from_biology_data(body_id, b) }
  end
end
