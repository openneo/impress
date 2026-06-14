require "vips"

module PetStateLabeling
  # Fetches eyes/mouth asset PNGs and compares them, for the visual tier.
  #
  # The art is a small drawing on a mostly-transparent 600x600 canvas, so we
  # trim to the drawn region before comparing — otherwise the empty canvas
  # dominates and washes out the signal. The distance is deliberately
  # *localized-sensitive*: a plain mean misses the few-pixel eyelash difference
  # that separates fem from masc eyes, so we add a term for the fraction of
  # pixels that differ strongly.
  #
  # Signatures are memoized per asset id, since each labeled reference asset is
  # compared against many targets.
  class ImageComparator
    SIGNATURE_SIZE = 96        # px; matches the gender leave-one-out experiment
    STRONG_DIFF = 20           # 0..255: what counts as a "real" pixel difference
    STRONG_DIFF_WEIGHT = 0.5   # how much the localized term counts

    NEOPETS_IMAGES_ORIGIN = "https://images.neopets.com"

    def initialize
      @signatures = {}
    end

    # A normalized grayscale Vips image for the asset's drawn region, or nil if
    # the image is missing/unfetchable/blank. Memoized.
    def signature(asset)
      return @signatures[asset.id] if @signatures.key?(asset.id)
      @signatures[asset.id] = build_signature(fetch_bytes(asset), asset)
    end

    # Build signatures for many assets up front, fetching their images in
    # parallel. Fetching dominates the cost, so this is dramatically faster than
    # calling #signature one at a time, and we only pay it once per asset.
    def prewarm(assets)
      pending = assets.reject { |asset| @signatures.key?(asset.id) }
      return if pending.empty?

      # Manifests must be loaded for image_url to resolve; do that in bulk.
      SwfAsset.preload_manifests(pending)

      bytes_by_id = fetch_many(pending)
      pending.each do |asset|
        @signatures[asset.id] = build_signature(bytes_by_id[asset.id], asset)
      end
    end

    # Localized-sensitive distance between two signatures (lower = more alike).
    # ~0 means effectively duplicate art.
    def distance(sig_a, sig_b)
      diff = (sig_a - sig_b).abs
      frac_strong = diff.relational_const(:more, STRONG_DIFF).avg / 255.0
      diff.avg + STRONG_DIFF_WEIGHT * frac_strong * 100
    end

    private

    def build_signature(bytes, asset)
      return nil if bytes.nil? || bytes.empty?

      img = Vips::Image.new_from_buffer(bytes, "")
      img = img.bandjoin(255) unless img.has_alpha?

      # Crop to the opaque region using the alpha channel.
      alpha = img.extract_band(img.bands - 1)
      left, top, width, height = alpha.find_trim(background: [0], threshold: 1)
      return nil if width <= 0 || height <= 0 # fully transparent

      gray = img.flatten(background: 255).colourspace("b-w")
      gray.crop(left, top, width, height).
        resize(SIGNATURE_SIZE.to_f / width, vscale: SIGNATURE_SIZE.to_f / height).
        copy_memory # materialize so repeated comparisons are cheap
    rescue Vips::Error, StandardError => error
      Rails.logger.warn "[PetStateLabeling] Could not build signature for " \
        "asset #{asset.id} (#{asset.image_url}): #{error.message}"
      nil
    end

    # Fetch many assets' image bytes concurrently, returning { asset_id => bytes }.
    def fetch_many(assets)
      bytes_by_id = {}
      DTIRequests.load_many(max_at_once: 10) do |semaphore|
        assets.each do |asset|
          semaphore.async do
            bytes_by_id[asset.id] = fetch_bytes(asset)
          end
        end
      end
      bytes_by_id
    end

    def fetch_bytes(asset)
      url = asset.image_url
      return nil if url.blank?

      if url.start_with?(NEOPETS_IMAGES_ORIGIN)
        # The local mirror self-heals empty/missing files by re-fetching.
        NeopetsMediaArchive.load_file(url)[:content]&.b
      else
        fetch_from_origin(url)&.b
      end
    rescue NeopetsMediaArchive::ResponseNotOK, StandardError => error
      Rails.logger.warn "[PetStateLabeling] Could not fetch image for asset " \
        "#{asset.id} (#{url}): #{error.message}"
      nil
    end

    # For non-images.neopets.com URLs (e.g. legacy aws.impress-asset-images),
    # fetch directly. DTIRequests needs an async context.
    def fetch_from_origin(url)
      bytes = nil
      Sync do
        DTIRequests.get(url) do |response|
          bytes = response.read if response.success?
        end
      end
      bytes
    end
  end
end
