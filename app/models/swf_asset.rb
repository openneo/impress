require 'fileutils'
require 'uri'
require 'utf8'

class SwfAsset < ActiveRecord::Base
  # We use the `type` column to mean something other than what Rails means!
  self.inheritance_column = nil
  
  PUBLIC_ASSET_DIR = File.join('swfs', 'outfit')
  LOCAL_ASSET_DIR = Rails.root.join('public', PUBLIC_ASSET_DIR)
  IMAGE_BUCKET = IMPRESS_S3.bucket('impress-asset-images')
  IMAGE_PERMISSION = 'public-read'
  IMAGE_HEADERS = {
    'Cache-Control' => 'max-age=315360000',
    'Content-Type' => 'image/png'
  }
  # This is the URL origin we should use when loading from images.neopets.com.
  # It can be overridden in .env as `NEOPETS_IMAGES_URL_ORIGIN`, to use our
  # asset proxy instead.
  NEOPETS_IMAGES_URL_ORIGIN = ENV['NEOPETS_IMAGES_URL_ORIGIN'] || 'http://images.neopets.com'

  IMAGE_SIZES = {
    :small => [150, 150],
    :medium => [300, 300],
    :large => [600, 600]
  }
  
  belongs_to :zone
  has_many :parent_swf_asset_relationships
  
  scope :includes_depth, -> { includes(:zone) }

  def local_swf_path
    LOCAL_ASSET_DIR.join(local_path_within_outfit_swfs)
  end

  def swf_image_dir
    @swf_image_dir ||= Rails.root.join('tmp', 'asset_images_before_upload', self.id.to_s)
  end

  def swf_image_path(size)
    swf_image_dir.join("#{size.join 'x'}.png")
  end

  def after_swf_conversion(images)
    images.each do |size, path|
      key = s3_key(size)
      print "Uploading #{key}..."
      IMAGE_BUCKET.put(
        key,
        File.open(path),
        {}, # meta headers
        IMAGE_PERMISSION, # permission
        IMAGE_HEADERS
      )
      puts "done."

      FileUtils.rm path
    end
    FileUtils.rmdir swf_image_dir

    self.converted_at = Time.now
    self.has_image = true
    self.save!
  end

  def s3_key(size)
    URI.encode("#{s3_path}/#{size.join 'x'}.png")
  end

  def s3_path
    "#{self['type']}/#{s3_partition_path}#{self.remote_id}"
  end

  def s3_url(size)
    "#{IMAGE_BUCKET.public_link}/#{s3_path}/#{size.join 'x'}.png"
  end

  PARTITION_COUNT = 3
  PARTITION_DIGITS = 3
  PARTITION_ID_LENGTH = PARTITION_COUNT * PARTITION_DIGITS
  def s3_partition_path
    (remote_id / 10**PARTITION_DIGITS).to_s.rjust(PARTITION_ID_LENGTH, '0').tap do |id_str|
      PARTITION_COUNT.times do |n|
        id_str.insert(PARTITION_ID_LENGTH - (n * PARTITION_DIGITS), '/')
      end
    end
  end
  
  def image_version
    converted_at.to_i
  end
  
  def image_url(size=IMAGE_SIZES[:large])
    host = ASSET_HOSTS[:swf_asset_images]
    size_key = size.join('x')
    
    "//#{host}/#{s3_path}/#{size_key}.png?#{image_version}"
  end
  
  def images
    IMAGE_SIZES.values.map { |size| {:size => size, :url => image_url(size)} }
  end

  attr_accessor :item

  has_one :contribution, :as => :contributed, :inverse_of => :contributed
  has_many :parent_swf_asset_relationships

  delegate :depth, :to => :zone
  
  def self.body_ids_fitting_standard
    @body_ids_fitting_standard ||= PetType.standard_body_ids + [0]
  end

  scope :fitting_body_id, ->(body_id) {
    where(arel_table[:body_id].in([body_id, 0]))
  }

  scope :fitting_standard_body_ids, -> {
    where(arel_table[:body_id].in(body_ids_fitting_standard))
  }

  scope :fitting_color, ->(color) {
    body_ids = PetType.select(:body_id).where(:color_id => color.id).map(&:body_id)
    body_ids << 0
    where(arel_table[:body_id].in(body_ids))
  }

  scope :biology_assets, -> { where(:type => PetState::SwfAssetType) }
  scope :object_assets, -> { where(:type => Item::SwfAssetType) }
  scope :for_item_ids, ->(item_ids) {
    joins(:parent_swf_asset_relationships).
      where(ParentSwfAssetRelationship.arel_table[:parent_id].in(item_ids))
  }
  scope :with_parent_ids, -> {
    select('swf_assets.*, parents_swf_assets.parent_id')
  }

  # To manually change the body ID without triggering the usual change to 0,
  # use this override method.
  def override_body_id(new_body_id)
    @body_id_overridden = true
    self.body_id = new_body_id
  end

  def local_url
    '/' + File.join(PUBLIC_ASSET_DIR, local_path_within_outfit_swfs)
  end

  def as_json(options={})
    json = {
      :id => remote_id,
      :type => type,
      :depth => depth,
      :body_id => body_id,
      :zone_id => zone_id,
      :zones_restrict => zones_restrict,
      :is_body_specific => body_specific?,
      # Now that we don't proactively convert images anymore, let's just always
      # say `has_image: true` when sending data to the frontend, so it'll use the
      # new URLs anyway!
      :has_image => true,
      :images => images
    }
    if options[:for] == 'wardrobe'
      json[:local_path] = local_url
    else
      json[:local_url] = local_url
    end
    json[:parent_id] = options[:parent_id] if options[:parent_id]
    json
  end

  def body_specific?
    self.zone.type_id < 3 || item_is_body_specific?
  end
  
  def item_is_body_specific?
    # Get items that we're already bound to in the database, and
    # also the one passed to us from the current modeling operation,
    # if any.
    #
    # NOTE: I know this has perf impact... it would be better for
    #       modeling to preload this probably? But oh well!
    items = parent_swf_asset_relationships.includes(:parent).where(parent_type: "Item").map { |r| r.parent }
    items << item if item

    # Return whether any of them is known to be body-specific.
    # This ensures that we always respect the explicitly_body_specific flag!
    return items.any? { |i| i.body_specific? }
  end

  def origin_pet_type=(pet_type)
    self.body_id = pet_type.body_id
  end

  def origin_biology_data=(data)
    Rails.logger.debug("my biology data is: #{data.inspect}")
    self.type = 'biology'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
    self.zones_restrict = data[:zones_restrict]
  end

  def origin_object_data=(data)
    Rails.logger.debug("my object data is: #{data.inspect}")
    self.type = 'object'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
  end

  def mall_data=(data)
    self.zone_id = data['zone'].to_i
    self.url = "https://images.neopets.com/#{data['url']}"
  end

  def self.from_wardrobe_link_params(ids)
    where((
      arel_table[:remote_id].in(ids[:biology]).and(arel_table[:type].eq('biology'))
    ).or(
      arel_table[:remote_id].in(ids[:object]).and(arel_table[:type].eq('object'))
    ))
  end

  before_create do
    # HACK: images.neopets.com no longer accepts requests over `http://`, and
    #       our dependencies don't support the version of HTTPS they want. So,
    #       we replace images.neopets.com with the NEOPETS_IMAGES_URL_ORIGIN
    #       specified in the secret `.env` file. (At time of writing, that's
    #       our proxy: `http://images.neopets-asset-proxy.openneo.net`.)
    modified_url = url.sub(/^https?:\/\/images.neopets.com/, NEOPETS_IMAGES_URL_ORIGIN)

    uri = URI.parse(modified_url)
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.get(uri.request_uri)
    rescue Exception => e
      raise DownloadError, e.message
    end
    if response.is_a? Net::HTTPSuccess
      new_local_path = File.join(LOCAL_ASSET_DIR, local_path_within_outfit_swfs)
      new_local_dir = File.dirname new_local_path
      content = +response.body
      FileUtils.mkdir_p new_local_dir
      File.open(new_local_path, 'w') do |f|
        f.print content
      end
    else
      begin
        response.error!
      rescue Exception => e
        raise DownloadError, "Error loading SWF at #{url}: #{e.message}"
      else
        raise DownloadError, "Error loading SWF at #{url}. Response: #{response.inspect}"
      end
    end
  end

  before_save do
    # If an asset body ID changes, that means more than one body ID has been
    # linked to it, meaning that it's probably wearable by all bodies.
    self.body_id = 0 if !@body_id_overridden && (!self.body_specific? || (!self.new_record? && self.body_id_changed?))
  end

  class DownloadError < Exception;end

  private

  def local_path_within_outfit_swfs
    uri = URI.parse(url)
    pieces = uri.path.split('/')
    relevant_pieces = pieces[4..7]
    relevant_pieces.unshift pieces[2]
    File.join(relevant_pieces)
  end
end
