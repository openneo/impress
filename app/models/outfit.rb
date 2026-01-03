class Outfit < ApplicationRecord
  has_many :item_outfit_relationships, :dependent => :destroy

  has_many :worn_item_outfit_relationships, -> { where(is_worn: true) },
    class_name: 'ItemOutfitRelationship'
  has_many :worn_items, through: :worn_item_outfit_relationships, source: :item

  has_many :closeted_item_outfit_relationships, -> { where(is_worn: false) },
    class_name: 'ItemOutfitRelationship'
  has_many :closeted_items, through: :closeted_item_outfit_relationships,
                            source: :item

  belongs_to :alt_style, optional: true
  belongs_to :pet_state, optional: true # We validate presence below!
  belongs_to :user, optional: true

  validates :name, :presence => {:if => :user_id}, :uniqueness => {:scope => :user_id, :if => :user_id}
  validates :pet_state, presence: {
    message: ->(object, _) do
      if object.biology
        "does not exist for " +
          "species ##{object.biology[:species_id]}, " +
          "color ##{object.biology[:color_id]}, " +
          "pose #{object.biology[:pose]}"
      else
        "must exist"
      end
    end
  }

  before_validation :ensure_unique_name, if: :user_id?

  attr_reader :biology
  delegate :pose, to: :pet_state
  delegate :pet_type, to: :pet_state
  delegate :color, to: :pet_type
  delegate :color_id, to: :pet_type
  delegate :species, to: :pet_type
  delegate :species_id, to: :pet_type

  scope :wardrobe_order, -> { order('starred DESC', :name) }
  
  class OutfitImage
    def initialize(image_versions)
      @image_versions = image_versions  
    end

    def url
      @image_versions[:large]
    end
    
    def large
      Version.new(@image_versions[:large])
    end
    
    def medium
      Version.new(@image_versions[:medium])
    end
    
    def small
      Version.new(@image_versions[:small])
    end
    
    Version = Struct.new(:url)
  end
  
  def image?
    true
  end
  
  def image
    OutfitImage.new(image_versions)
  end
  
  IMAGE_URL_TEMPLATE = Addressable::Template.new(
    Rails.configuration.impress_2020_origin + 
    "/api/outfitImage{?id,size,updatedAt}"
  )
  def image_versions
    if Rails.env.production?
      # Now, instead of using the saved outfit to S3, we're using out the
      # DTI 2020 API + CDN cache version. We use openneo-assets.net to get
      # around a bug on Neopets petpages with openneo.net URLs.
      base_url = "https://outfits.openneo-assets.net/outfits" +
        "/#{CGI.escape id.to_s}" +
        "/v/#{CGI.escape updated_at.to_i.to_s}"
      {
        large: "#{base_url}/600.png",
        medium: "#{base_url}/300.png",
        small: "#{base_url}/150.png",
      }
    else
      # In development, just talk to our local Impress 2020 directly.
      build_url = -> size {
        IMAGE_URL_TEMPLATE.expand(
          id: id, size: size, updatedAt: updated_at.to_i
        ).to_s
      }
      {
        large: build_url.call("600"),
        medium: build_url.call("300"),
        small: build_url.call("150"),
      }
    end

    # NOTE: Below is the previous code that uses the saved outfits!
    # {}.tap do |versions|
    #   versions[:large] = image.url
    #   image.versions.each { |name, version| versions[name] = version.url }
    # end
  end
  
  def as_json(more_options={})
    serializable_hash(
      only: [:id, :name, :pet_state_id, :starred, :created_at, :updated_at,
        :alt_style_id],
      methods: [:color_id, :species_id, :pose, :item_ids, :user]
    )
  end

  def biology=(biology)
    @biology = biology.slice(:species_id, :color_id, :pose, :pet_state_id)

    begin
      if @biology[:pet_state_id]
        self.pet_state = PetState.find(@biology[:pet_state_id])
      else
        pet_type = PetType.where(
          species_id: @biology[:species_id],
          color_id: @biology[:color_id],
        ).first!
        self.pet_state = pet_type.pet_states.with_pose(@biology[:pose]).
          emotion_order.first!
      end
    rescue ActiveRecord::RecordNotFound
      # If there's no such pet state (which shouldn't happen normally in-app),
      # we don't set `pet_state` but we keep `@biology` for validation.
    end
  end

  def item_ids
    rels = item_outfit_relationships
    {
      worn: rels.filter { |r| r.is_worn? }.map { |r| r.item_id },
      closeted: rels.filter { |r| !r.is_worn? }.map { |r| r.item_id }
    }
  end

  def item_ids=(item_ids)
    # Ensure there are no duplicates between the worn/closeted IDs. If an ID is
    # present in both, it's kept in `worn` and removed from `closeted`.
    worn_item_ids = item_ids.fetch(:worn, []).uniq
    closeted_item_ids = item_ids.fetch(:closeted, []).uniq
    closeted_item_ids.reject! { |id| worn_item_ids.include?(id) }

    # Set the worn and closeted item outfit relationships. If there are any
    # others attached to this outfit, they are implicitly deleted.
    new_relationships = []
    new_relationships += worn_item_ids.map do |item_id|
      ItemOutfitRelationship.new(item_id: item_id, is_worn: true)
    end
    new_relationships += closeted_item_ids.map do |item_id|
      ItemOutfitRelationship.new(item_id: item_id, is_worn: false)
    end
    self.item_outfit_relationships = new_relationships
  end

  def item_appearances(...)
    Item.appearances_for(worn_items, pet_type, ...).values
  end

  def visible_layers
    # Step 1: Choose biology layers - use alt style if present, otherwise pet state
    if alt_style
      biology_layers = alt_style.swf_assets.includes(:zone).to_a
      body = alt_style
      using_alt_style = true
    else
      biology_layers = pet_state.swf_assets.includes(:zone).to_a
      body = pet_type
      using_alt_style = false
    end

    # Step 2: Load item appearances for the appropriate body
    item_appearances = Item.appearances_for(
      worn_items,
      body,
      swf_asset_includes: [:zone]
    ).values
    item_layers = item_appearances.map(&:swf_assets).flatten

    # For alt styles, only body_id=0 items are compatible
    if using_alt_style
      item_layers.reject! { |sa| sa.body_id != 0 }
    end

    # Step 3: Apply restriction rules
    biology_restricted_zone_ids = biology_layers.map(&:restricted_zone_ids).
      flatten.to_set
    item_restricted_zone_ids = item_appearances.
      map(&:restricted_zone_ids).flatten.to_set

    # Rule 3a: When an item restricts a zone, it hides biology layers of the same zone.
    # We use this to e.g. make a hat hide a hair ruff.
    #
    # NOTE: Items' restricted layers also affect what items you can wear at
    #       the same time. We don't enforce anything about that here, and
    #       instead assume that the input by this point is valid!
    biology_layers.reject! { |sa| item_restricted_zone_ids.include?(sa.zone_id) }

    # Rule 3b: When a biology appearance restricts a zone, or when the pet is
    # Unconverted, it makes body-specific items incompatible. We use this to
    # disallow UCs from wearing certain body-specific Biology Effects, Statics,
    # etc, while still allowing non-body-specific items in those zones! (I think
    # this happens for some Invisible pet stuff, too?)
    #
    # TODO: We shouldn't be *hiding* these zones, like we do with items; we
    #       should be doing this way earlier, to prevent the item from even
    #       showing up even in search results!
    #
    # NOTE: This can result in both biology layers and items occupying the same
    #       zone, like Static, so long as the item isn't body-specific! That's
    #       correct, and the item layer should be on top! (Here, we implement
    #       it by placing item layers second in the list, and rely on JS sort
    #       stability, and *then* rely on the UI to respect that ordering when
    #       rendering them by depth. Not great! 😅)
    #
    # NOTE: We used to also include the biology appearance's *occupied* zones in
    #       this condition, not just the restricted zones, as a sensible
    #       defensive default, even though we weren't aware of any relevant
    #       items. But now we know that actually the "Bruce Brucey B Mouth"
    #       occupies the real Mouth zone, and still should be visible and
    #       above biology layers! So, we now only check *restricted* zones.
    #
    # NOTE: UCs used to implement their restrictions by listing specific
    #       zones, but it seems that the logic has changed to just be about
    #       UC-ness and body-specific-ness, and not necessarily involve the
    #       set of restricted zones at all. (This matters because e.g. UCs
    #       shouldn't show _any_ part of the Rainy Day Umbrella, but most UCs
    #       don't restrict Right-Hand Item (Zone 49).) Still, I'm keeping the
    #       zone restriction case running too, because I don't think it
    #       _hurts_ anything, and I'm not confident enough in this conclusion.
    #
    # TODO: Do Invisibles follow this new rule like UCs, too? Or do they still
    #       use zone restrictions?
    if pet_state.pose === "UNCONVERTED"
      item_layers.reject! { |sa| sa.body_specific? }
    else
      item_layers.reject! { |sa| sa.body_specific? &&
        biology_restricted_zone_ids.include?(sa.zone_id) }
    end

    # Rule 3c: A biology appearance can also restrict its own zones. The Wraith
    # Uni is an interesting example: it has a horn, but its zone restrictions
    # hide it!
    biology_layers.reject! { |sa| biology_restricted_zone_ids.include?(sa.zone_id) }

    # Step 4: Sort by depth and return
    (biology_layers + item_layers).sort_by(&:depth)
  end

  def wardrobe_params
    params = {
      name: name,
      color: color_id,
      species: species_id,
      pose: pose,
      state: pet_state_id,
      objects: worn_item_ids,
      closet: closeted_item_ids,
    }
    params[:style] = alt_style_id if alt_style_id.present?
    params
  end

  def ensure_unique_name
    # If no name was provided, start with "Untitled outfit".
    self.name = "Untitled outfit" if name.blank?

    # Strip whitespace from the name.
    self.name.strip!

    # Get the base name of the provided name, without any "(1)" suffixes.
    base_name = name.sub(/\s*\([0-9]+\)\z/, '')

    # Find the user's other outfits that start with the same base name, and get
    # *their* names, with whitespace stripped.
    existing_outfits = self.user.outfits.
      where("name LIKE ?", Outfit.sanitize_sql_like(base_name) + "%")
    existing_outfits = existing_outfits.where("id != ?", id) unless id.nil?
    existing_names = existing_outfits.map(&:name).map(&:strip)

    # Try the provided name first, but if it's taken, add a "(1)" suffix and
    # keep incrementing it until it's not.
    i = 1
    while existing_names.include?(name)
      self.name = "#{base_name} (#{i})"
      i += 1
    end
  end
end
