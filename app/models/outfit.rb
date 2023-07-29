class Outfit < ActiveRecord::Base
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
  
  # NOTE: We no longer save images, but we've left the code here for now.
  #       The `image` method below simulates the previous API for the rest
  #       of the app!
  # mount_uploader :image, OutfitImageUploader
  # before_save :update_enqueued_image
  # after_commit :enqueue_image!
  
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
  
  # Returns the array of SwfAssets representing each layer of the output image,
  # ordered from bottom to top. Careful: this method is memoized, so if the
  # image layers change after its first call we'll get bad results.
  def image_layers
    @image_layers ||= visible_assets_with_images.sort { |a, b| a.depth <=> b.depth }
  end
  
  # Creates and writes the thumbnail images for this outfit iff the new image
  # would be different than the current one. (Writes to file in development,
  # S3 in production.) If the image is updated, updates the image layers hash
  # and runs #save! on the record, so any other changes will also be saved.
  def write_image!
    if image_layers_dirty?
      image = Tempfile.open(['outfit_image', '.png'])
      begin
        create_image! image
        self.image_layers_hash = generate_image_layers_hash
        self.image = image
        self.image_enqueued = false
        save!
      ensure
        image.close!
      end
    end
    
    self.image
  end
  
  # Enqueue an image write iff the new image would be different than the
  # current one.
  def enqueue_image!
    Resque.enqueue(OutfitImageUpdate, id)
  end
  
  def update_enqueued_image
    self.image_enqueued = (image_layers_dirty?)
    true
  end
  
  def s3_key(size)
    URI.encode("#{id}/#{size.join 'x'}.png")
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
  
  protected
  
  # Creates a 600x600 PNG image of this outfit, writing to the given output
  # file.
  def create_image!(output)
    unless image_layers.empty?
      temp_image_files = Parallel.map(image_layers, :in_threads => 8) do |swf_asset|
        image_file = Tempfile.open(['outfit_layer', '.png'])
        begin
          write_temp_swf_asset_image!(swf_asset, image_file)
        rescue RightAws::AwsError
          nil # skip broken images
        else
          image_file
        ensure
          image_file.close
        end
      end.compact # remove nils for broken images
      
      # Here we do some awkwardness to get the exact ImageMagick command we
      # want, though it's still less awkward than handling the command
      # ourselves. Give all of the temporary images as input, flatten them and
      # write them to the output path.
      command = MiniMagick::CommandBuilder.new('convert')
      temp_image_files.each { |image_file| command.push image_file.path }
      command.layers 'flatten'
      command.push output.path
      
      # Though the above command really is sufficient, we still need a dummy
      # image to handle execution.
      output_image = MiniMagick::Image.new(output.path)
      output_image.run(command)
      
      temp_image_files.each(&:unlink)
    else
      output.close
    end
  end
  
  def visible_assets
    biology_assets = pet_state.swf_assets.includes(:zone)
    object_assets = SwfAsset.object_assets.
      fitting_body_id(pet_state.pet_type.body_id).for_item_ids(worn_item_ids).
      includes(:zone)
    
    # Now for fun with bitmasks! Rather than building a bunch of integer arrays
    # here, we instead go low-level and use bit-level operations. Build the
    # bitmask by parsing the binary string (reversing it to get the lower zone
    # numbers on the right), then OR them all together to get the mask
    # representing all the restricted zones. (Note to self: why not just store
    # in this format in the first place?)
    restrictors = biology_assets + worn_items
    restricted_zones_mask = restrictors.inject(0) do |mask, restrictor|
      mask | restrictor.zones_restrict.reverse.to_i(2)
    end
    
    # Now, check each asset's zone is not restricted in the bitmask using
    # bitwise operations: shift 1 to the zone_id position, then AND it with
    # the restricted zones mask. If we get 0, then the bit for that zone ID was
    # not turned on, so the zone is not restricted and this asset is visible.
    all_assets = biology_assets + object_assets
    all_assets.select { |a| (1 << (a.zone_id - 1)) & restricted_zones_mask == 0 }
  end
  
  def visible_assets_with_images
    visible_assets.select(&:has_image?)
  end
  
  # Generate 8-char hex digest representing visible image layers for this outfit.
  # Hash function should be decently collision-resistant.
  def generate_image_layers_hash
    @generated_image_layers_hash ||=
      Digest::MD5.hexdigest(image_layers.map(&:id).join(',')).first(8)
  end
  
  def image_layers_dirty?
    generate_image_layers_hash != self.image_layers_hash
  end
  
  IMAGE_BASE_SIZE = [600, 600]
  def write_temp_swf_asset_image!(swf_asset, file)
    key = swf_asset.s3_key(IMAGE_BASE_SIZE)
    bucket = SwfAsset::IMAGE_BUCKET
    data = bucket.get(key)
    file.binmode # write in binary mode
    file.truncate(0) # clear the file
    file.write data # write the new data
  end
end

