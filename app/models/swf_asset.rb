require 'addressable/template'
require 'async'
require 'async/barrier'
require 'async/semaphore'
require 'fileutils'
require 'uri'

class SwfAsset < ApplicationRecord
  # We use the `type` column to mean something other than what Rails means!
  self.inheritance_column = nil

  # Used in `item_is_body_specific?`. (TODO: Could we refactor this out?)
  attr_accessor :item
  
  belongs_to :zone
  has_many :parent_swf_asset_relationships
  has_one :contribution, :as => :contributed, :inverse_of => :contributed

  before_validation :normalize_manifest_url, if: :manifest_url?

  delegate :depth, :to => :zone

  scope :biology_assets, -> { where(:type => PetState::SwfAssetType) }
  scope :object_assets, -> { where(:type => Item::SwfAssetType) }

  CANVAS_MOVIE_IMAGE_URL_TEMPLATE = Addressable::Template.new(
    Rails.configuration.impress_2020_origin +
    "/api/assetImage{?libraryUrl,size}"
  )
  LEGACY_IMAGE_URL_TEMPLATE = Addressable::Template.new(
    "https://aws.impress-asset-images.openneo.net/{type}" +
    "/{id1}/{id2}/{id3}/{id}/{size}x{size}.png?v2-{time}"
  )

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
      svg: manifest_asset_urls[:svg],
      canvas_library: manifest_asset_urls[:js],
      manifest: manifest_url,
    }
  end

  def manifest
    @manifest ||= load_manifest
  end

  def preload_manifest(save_changes: true)
    load_manifest(return_content: false, save_changes:)
  end

  def load_manifest(return_content: true, save_changes: true)
    return nil if manifest_url.blank?

    # If we recently tried loading the manifest and got a 4xx HTTP status code
    # (e.g. a 404, there's a surprising amount of these!), don't try again. But
    # after enough time passes, if this is called again, we will!
    #
    # (We always retry 5xx errors, on the assumption that they probably
    # represent intermittent failures, whereas 4xx errors are not likely to
    # succeed just by retrying.)
    if manifest_loaded_at.present?
      last_try_was_4xx =(400...500).include?(manifest_status_code)
      last_try_was_recent = (Time.now - manifest_loaded_at) <= 1.day
      if last_try_was_4xx and last_try_was_recent
        Rails.logger.debug "Skipping loading manifest for asset #{id}: " +
          "last try was status #{manifest_status_code} at #{manifest_loaded_at}"
        return nil
      end
    end

    # Try loading the manifest. If we fail, record that we failed and return.
    begin
      Sync do |task|
        task.with_timeout(5) do
          NeopetsMediaArchive.load_file(manifest_url, return_content:)
        end
      end => {content:, source:}
    rescue Async::TimeoutError
      # If the request times out, record nothing and return nothing! We'll try
      # again sometime, on the assumption that this is intermittent.
      Rails.logger.warn("Timed out loading manifest for asset #{id}")
      return nil
    rescue NeopetsMediaArchive::ResponseNotOK => error
      Rails.logger.warn "Failed to load manifest for asset #{id}: " +
        error.message
      self.manifest_loaded_at = Time.now
      self.manifest_status_code = error.status
      save! if save_changes
      return nil
    end

    # If this was a fresh load over the network (or for some reason we're
    # missing the timestamp), record that we succeeded.
    if source == "network" || manifest_loaded_at.blank?
      self.manifest_loaded_at = Time.now
      self.manifest_status_code = 200
      save! if save_changes
    end

    return nil unless return_content # skip parsing if not needed!

    # Parse the manifest as JSON, and return it!
    begin
      JSON.parse(content)
    rescue JSON::ParserError => error
      Rails.logger.warn "Failed to parse manifest for asset #{id}: " +
        error.message
      return nil
    end
  end

  MANIFEST_BASE_URL = Addressable::URI.parse("https://images.neopets.com")
  def manifest_asset_urls
    return {} unless manifest.present?

    begin
      # Organize the asset URLs by file extension, convert them from paths to
      # full URLs, and grab the ones we want.
      assets_by_ext = manifest["cpmanifest"]["assets"][0]["asset_data"].
        group_by { |a| a["file_ext"].to_sym }.
        transform_values do |assets|
          assets.map { |a| (MANIFEST_BASE_URL + a["url"]).to_s }
        end

      if assets_by_ext[:js].present?
        # If a JS asset is present, assume any other assets are supporting
        # assets, and skip them. (e.g. if there's a PNG, it's likely to be an
        # "atlas" file used in the animation, rather than a thumbnail.)
        #
        # NOTE: We take the last one, because sometimes there are multiple JS
        # assets in the same manifest, and earlier ones are broken and later
        # ones are fixed. I don't know the logic exactly, but that's what we've
        # seen!
        { js: assets_by_ext[:js].last }
      else
        # Otherwise, return the first PNG and the first SVG. (Unlike the JS
        # case, it's important to choose the *first* PNG, because sometimes
        # reference art is included in the manifest, like with the Stealthy
        # Eyrie Shirt's asset 304486_b28cae0d76.)
        {
          png: assets_by_ext.fetch(:png, []).first,
          svg: assets_by_ext.fetch(:svg, []).first,
        }
      end
    rescue StandardError => error
      Rails.logger.error "Could not read URLs from manifest: #{error.full_message}"
      return {}
    end
  end

  def image_url
    # Use the PNG image from the manifest, if one exists.
    return manifest_asset_urls[:png] if manifest_asset_urls[:png].present?

    # Or, if this is a canvas movie, let Impress 2020 generate a PNG for us.
    return canvas_movie_image_url if manifest_asset_urls[:js].present?

    # Otherwise, if we don't have the manifest or it doesn't have the files we
    # need, fall back to the Classic DTI image storage, which was generated
    # from the SWFs via an old version of gnash (or sometimes manually
    # overridden). It's less accurate, but well-tested to generally work okay,
    # and it's the only image we have for assets not yet converted to HTML5.
    #
    # NOTE: We've stopped generating these images for new assets! This is
    #       mainly for old assets not yet converted to HTML5.
    #
    # NOTE: If you're modeling from a fresh development database, `has_image?`
    #       might be false even though we *do* have a saved copy of the image
    #       available in production. But if you're using the public modeling
    #       data exported from production, then this check should be fine!
    #
    # TODO: Rename `has_image?` to `has_legacy_image?`.
    return legacy_image_url if has_image?

    # Otherwise, there's no image URL.
    nil
  end

  def canvas_movie_image_url
    return nil unless manifest_asset_urls[:js]

    CANVAS_MOVIE_IMAGE_URL_TEMPLATE.expand(
      libraryUrl: manifest_asset_urls[:js],
      size: 600,
    ).to_s
  end

  def legacy_image_url
    return nil unless has_image?

    padded_id = remote_id.to_s.rjust(12, "0")
    LEGACY_IMAGE_URL_TEMPLATE.expand(
      type: type,
      id1: padded_id[0...3],
      id2: padded_id[3...6],
      id3: padded_id[6...9],
      id: remote_id,
      size: "600",
      time: converted_at.to_i,
    ).to_s
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

  # To manually change the body ID without triggering the usual change to 0,
  # use this override method. (This is intended for use from the console.)
  def override_body_id(new_body_id)
    @body_id_overridden = true
    self.body_id = new_body_id
  end

  def self.from_biology_data(body_id, data)
    remote_id = data[:part_id].to_i
    swf_asset = SwfAsset.find_or_initialize_by type: 'biology',
      remote_id: remote_id
    swf_asset.body_id = body_id
    swf_asset.origin_biology_data = data
    swf_asset
  end

  def self.from_wardrobe_link_params(ids)
    where((
      arel_table[:remote_id].in(ids[:biology]).and(arel_table[:type].eq('biology'))
    ).or(
      arel_table[:remote_id].in(ids[:object]).and(arel_table[:type].eq('object'))
    ))
  end

  # Given a list of SWF assets, ensure all of their manifests are loaded, with
  # fast concurrent execution!
  def self.preload_manifests(swf_assets)
    # Blocks all tasks beneath it.
    barrier = Async::Barrier.new

    Sync do
      # Only allow 10 manifests to be loaded at a time.
      semaphore = Async::Semaphore.new(10, parent: barrier)

      # Load all the manifests in async tasks. This will load them 10 at a time
      # rather than all at once (because of the semaphore), and the
      # NeopetsMediaArchive will share a pool of persistent connections for
      # them.
      swf_assets.map do |swf_asset|
        semaphore.async do
          begin
            # Don't save changes in this big async situation; we'll do it all
            # in one batch after, to avoid too much database concurrency!
            swf_asset.preload_manifest(save_changes: false)
          rescue StandardError => error
            Rails.logger.error "Could not preload manifest for asset " + 
              "#{swf_asset.id} (#{swf_asset.manifest_url}): #{error.message}"
          end
        end
      end

      # Wait until all tasks are done.
      barrier.wait
    ensure
      barrier.stop # If something goes wrong, clean up all tasks.
    end

    SwfAsset.transaction do
      swf_assets.select(&:changed?).each(&:save!)
    end
  end

  before_save do
    # If an asset body ID changes, that means more than one body ID has been
    # linked to it, meaning that it's probably wearable by all bodies.
    self.body_id = 0 if !@body_id_overridden && (!self.body_specific? || (!self.new_record? && self.body_id_changed?))
  end

  class DownloadError < Exception;end
end
