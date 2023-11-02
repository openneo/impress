class Outfit < ApplicationRecord
  has_many :item_outfit_relationships, :dependent => :destroy
  has_many :worn_item_outfit_relationships, -> { where(is_worn: true) },
    class_name: 'ItemOutfitRelationship'
  has_many :worn_items, through: :worn_item_outfit_relationships, source: :item

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
  delegate :color, to: :pet_state

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
  
  def image_versions
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

    # NOTE: Below is the previous code that uses the saved outfits!
    # {}.tap do |versions|
    #   versions[:large] = image.url
    #   image.versions.each { |name, version| versions[name] = version.url }
    # end
  end
  
  def as_json(more_options={})
    serializable_hash(
      only: [:id, :name, :pet_state_id, :starred, :created_at, :updated_at],
      methods: [:color_id, :species_id, :pose, :item_ids, :user]
    )
  end

  def color_id
    pet_state.pet_type.color_id
  end

  def species_id
    pet_state.pet_type.species_id
  end

  def pose
    pet_state.pose
  end

  def biology=(biology)
    @biology = biology.slice(:species_id, :color_id, :pose)

    begin
      pet_type = PetType.where(
        species_id: @biology[:species_id],
        color_id: @biology[:color_id],
      ).first!
      self.pet_state = pet_type.pet_states.with_pose(@biology[:pose]).
        emotion_order.first!
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

  def ensure_unique_name
    # If no name was provided, start with "Untitled outfit".
    self.name = "Untitled outfit" if name.blank?

    # Strip whitespace from the name.
    self.name.strip!

    # Get the base name of the provided name, without any "(1)" suffixes.
    base_name = name.sub(/\s*\([0-9]+\)$/, '')

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
