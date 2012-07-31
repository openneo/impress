require 'fileutils'
require 'uri'
require 'utf8'

class SwfAsset < ActiveRecord::Base
  PUBLIC_ASSET_DIR = File.join('swfs', 'outfit')
  LOCAL_ASSET_DIR = Rails.root.join('public', PUBLIC_ASSET_DIR)
  IMAGE_BUCKET = IMPRESS_S3.bucket('impress-asset-images')
  IMAGE_PERMISSION = 'public-read'
  IMAGE_HEADERS = {
    'Cache-Control' => 'max-age=315360000',
    'Content-Type' => 'image/png'
  }
  NEOPETS_ASSET_SERVER = 'http://images.neopets.com'

  set_inheritance_column 'inheritance_type'

  IMAGE_SIZES = {
    :small => [150, 150],
    :medium => [300, 300],
    :large => [600, 600]
  }

  include SwfConverter
  converts_swfs :size => IMAGE_SIZES[:large], :output_sizes => IMAGE_SIZES.values

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
    
    "http://#{host}/#{s3_path}/#{size_key}.png?#{image_version}"
  end
  
  def images
    IMAGE_SIZES.values.map { |size| {:size => size, :url => image_url(size)} }
  end

  def convert_swf_if_not_converted!
    if needs_conversion?
      convert_swf!
      true
    else
      false
    end
  end

  def request_image_conversion!
    if image_requested?
      false
    else
      Resque.enqueue(AssetImageConversionRequest, self.id)
      self.image_requested = true
      save!
      true
    end
  end

  def report_broken
    if image_pending_repair?
      return false
    end

    Resque.enqueue(AssetImageConversionRequest::OnBrokenImageReport, self.id)
    self.reported_broken_at = Time.now
    self.save
  end

  def needs_conversion?
    !has_image? || image_pending_repair?
  end

  REPAIR_PENDING_EXPIRES = 1.hour
  def image_pending_repair?
    reported_broken_at &&
      (converted_at.nil? || reported_broken_at > converted_at) &&
      reported_broken_at > REPAIR_PENDING_EXPIRES.ago
  end

  attr_accessor :item

  has_one :contribution, :as => :contributed
  has_many :parent_swf_asset_relationships

  delegate :depth, :to => :zone
  
  def self.body_ids_fitting_standard
    @body_ids_fitting_standard ||= PetType.standard_body_ids + [0]
  end

  scope :fitting_body_id, lambda { |body_id|
    where(arel_table[:body_id].in([body_id, 0]))
  }

  scope :fitting_standard_body_ids, lambda {
    where(arel_table[:body_id].in(body_ids_fitting_standard))
  }

  scope :fitting_color, lambda { |color|
    body_ids = PetType.select(:body_id).where(:color_id => color.id).map(&:body_id)
    where(arel_table[:body_id].in(body_ids))
  }

  scope :biology_assets, where(:type => PetState::SwfAssetType)
  scope :object_assets, where(:type => Item::SwfAssetType)
  scope :for_item_ids, lambda { |item_ids|
    joins(:parent_swf_asset_relationships).
      where(ParentSwfAssetRelationship.arel_table[:parent_id].in(item_ids))
  }

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
      :has_image => has_image?,
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
    self.zone.type_id < 3
  end

  def zone
    Zone.find(zone_id)
  end

  def origin_pet_type=(pet_type)
    self.body_id = pet_type.body_id
  end

  def origin_biology_data=(data)
    self.type = 'biology'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
    self.zones_restrict = data[:zones_restrict]
  end

  def origin_object_data=(data)
    self.type = 'object'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
  end

  def mall_data=(data)
    self.zone_id = data['zone'].to_i
    self.url = "#{NEOPETS_ASSET_SERVER}/#{data['url']}"
  end

  before_create do
    uri = URI.parse url
    begin
      response = Net::HTTP.get_response(uri)
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
    self.body_id = 0 if !self.body_specific? || (!self.new_record? && self.body_id_changed?)
  end

  after_commit :on => :create do
    Resque.enqueue(AssetImageConversionRequest::OnCreation, self.id)
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

