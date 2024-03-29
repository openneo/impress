require 'fileutils'
require 'uri'

class SwfAsset < ApplicationRecord
  # We use the `type` column to mean something other than what Rails means!
  self.inheritance_column = nil

  IMAGE_SIZES = {
    :small => [150, 150],
    :medium => [300, 300],
    :large => [600, 600]
  }
  
  belongs_to :zone
  has_many :parent_swf_asset_relationships
  
  scope :includes_depth, -> { includes(:zone) }

  before_validation :normalize_manifest_url, if: :manifest_url?

  def swf_image_dir
    @swf_image_dir ||= Rails.root.join('tmp', 'asset_images_before_upload', self.id.to_s)
  end

  def swf_image_path(size)
    swf_image_dir.join("#{size.join 'x'}.png")
  end

  PARTITION_COUNT = 3
  PARTITION_DIGITS = 3
  PARTITION_ID_LENGTH = PARTITION_COUNT * PARTITION_DIGITS
  def partition_path
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
    
    image_dir = "#{self['type']}/#{partition_path}#{self.remote_id}"
    "//#{host}/#{image_dir}/#{size_key}.png?#{image_version}"
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

  def as_json(options={})
    super({
      only: [:id, :known_glitches],
      methods: [:zone, :restricted_zones, :urls]
    }.merge(options))
  end

  def urls
    {
      swf: url,
      png: image_url,
      manifest: manifest_url,
    }
  end

  def known_glitches
    self[:known_glitches].split(',')
  end

  def known_glitches=(new_known_glitches)
    if new_known_glitches.is_a? Array
      new_known_glitches = new_known_glitches.join(',')
    end
    self[:known_glitches] = new_known_glitches
  end

  def restricted_zone_ids
    [].tap do |ids|
      zones_restrict.chars.each_with_index do |bit, index|
        ids << index + 1 if bit == "1"
      end
    end
  end

  def restricted_zones
    Zone.where(id: restricted_zone_ids)
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
    self.manifest_url = data[:manifest]
  end

  def origin_object_data=(data)
    Rails.logger.debug("my object data is: #{data.inspect}")
    self.type = 'object'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
    self.zones_restrict = ""
    self.manifest_url = data[:manifest]
  end

  def normalize_manifest_url
    parsed_manifest_url = Addressable::URI.parse(manifest_url)
    parsed_manifest_url.scheme = "https"
    self.manifest_url = parsed_manifest_url.to_s
  end

  def self.from_wardrobe_link_params(ids)
    where((
      arel_table[:remote_id].in(ids[:biology]).and(arel_table[:type].eq('biology'))
    ).or(
      arel_table[:remote_id].in(ids[:object]).and(arel_table[:type].eq('object'))
    ))
  end

  before_save do
    # If an asset body ID changes, that means more than one body ID has been
    # linked to it, meaning that it's probably wearable by all bodies.
    self.body_id = 0 if !@body_id_overridden && (!self.body_specific? || (!self.new_record? && self.body_id_changed?))
  end

  class DownloadError < Exception;end
end
