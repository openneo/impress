class Outfit < ApplicationRecord
  has_many :item_outfit_relationships, :dependent => :destroy
  has_many :worn_item_outfit_relationships, -> { where(is_worn: true) },
    :class_name => 'ItemOutfitRelationship'
  has_many :worn_items, :through => :worn_item_outfit_relationships, :source => :item
  belongs_to :pet_state
  belongs_to :user

  validates :name, :presence => {:if => :user_id}, :uniqueness => {:scope => :user_id, :if => :user_id}
  validates :pet_state, :presence => true

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
    serializable_hash :only => [:id, :name, :pet_state_id, :starred],
      :methods => [:color_id, :species_id, :worn_and_unworn_item_ids,
                   :image_versions, :image_enqueued, :image_layers_hash]
  end

  def closet_item_ids
    item_outfit_relationships.map(&:item_id)
  end

  def color_id
    pet_state.pet_type.color_id
  end

  def species_id
    pet_state.pet_type.species_id
  end

  def to_query
    ids = self.worn_and_unworn_item_ids
    
    {
      :closet => ids[:worn] + ids[:unworn],
      :color => color_id,
      :objects => ids[:worn],
      :species => species_id,
      :state => pet_state_id
    }.to_query
  end

  def worn_and_unworn_item_ids
    {:worn => [], :unworn => []}.tap do |output|
      item_outfit_relationships.each do |rel|
        key = rel.is_worn? ? :worn : :unworn
        output[key] << rel.item_id
      end
    end
  end

  def worn_and_unworn_item_ids=(all_item_ids)
    new_rels = []
    all_item_ids.each do |key, item_ids|
      worn = key == 'worn'
      unless item_ids.blank?
        item_ids.each do |item_id|
          rel = ItemOutfitRelationship.new
          rel.item_id = item_id
          rel.is_worn = worn
          new_rels << rel
        end
      end
    end
    self.item_outfit_relationships = new_rels
  end

  def self.build_for_user(user, params)
    Outfit.new.tap do |outfit|
      name = params.delete(:name)
      starred = params.delete(:starred)
      anonymous = params.delete(:anonymous) == "true"
      if user && !anonymous
        outfit.user = user
        outfit.name = name
        outfit.starred = starred
      end
      outfit.attributes = params
    end
  end
end
