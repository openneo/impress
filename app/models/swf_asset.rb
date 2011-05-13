class SwfAsset < ActiveRecord::Base
  PUBLIC_ASSET_DIR = File.join('swfs', 'outfit')
  LOCAL_ASSET_DIR = Rails.root.join('public', PUBLIC_ASSET_DIR)
  PUBLIC_IMAGE_DIR = File.join('images', 'outfit')
  LOCAL_IMAGE_DIR = Rails.root.join('public', PUBLIC_IMAGE_DIR)
  NEOPETS_ASSET_SERVER = 'http://images.neopets.com'

  set_inheritance_column 'inheritance_type'

  include SwfConverter
  converts_swfs :size => [600, 600], :output_sizes => [[150, 150], [300, 300], [600, 600]]

  def local_swf_path
    LOCAL_ASSET_DIR.join(local_path_within_outfit_swfs)
  end

  def swf_image_path(size)
    base_dir = File.dirname(local_path_within_outfit_swfs)
    image_dir = LOCAL_IMAGE_DIR.join(base_dir).join(id.to_s)
    image_dir.join("#{id}_#{size[0]}x#{size[1]}.png")
  end

  attr_accessor :item

  has_one :contribution, :as => :contributed
  has_many :object_asset_relationships, :class_name => 'ParentSwfAssetRelationship',
    :conditions => {:swf_asset_type => 'object'}

  delegate :depth, :to => :zone

  scope :fitting_body_id, lambda { |body_id|
    where(arel_table[:body_id].in([body_id, 0]))
  }

  BodyIdsFittingStandard = PetType::StandardBodyIds + [0]
  scope :fitting_standard_body_ids, lambda {
    where(arel_table[:body_id].in(BodyIdsFittingStandard))
  }

  scope :fitting_color, lambda { |color|
    body_ids = PetType.select(:body_id).where(:color_id => color.id).map(&:body_id)
    where(arel_table[:body_id].in(body_ids))
  }

  scope :biology_assets, where(arel_table[:type].eq(PetState::SwfAssetType))
  scope :object_assets, where(arel_table[:type].eq(Item::SwfAssetType))
  scope :for_item_ids, lambda { |item_ids|
    joins(:object_asset_relationships).
      where(ParentSwfAssetRelationship.arel_table[:parent_id].in(item_ids))
  }

  def local_url
    '/' + File.join(PUBLIC_ASSET_DIR, local_path_within_outfit_swfs)
  end

  def as_json(options={})
    json = {
      :id => id,
      :depth => depth,
      :body_id => body_id,
      :zone_id => zone_id,
      :zones_restrict => zones_restrict,
      :is_body_specific => body_specific?
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
      content = response.body.force_encoding 'utf-8'
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

