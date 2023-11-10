class AddManifestUrlToSwfAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :swf_assets, :manifest_url, :string

    # Okay, this is a big one to run upward! We're going to infer the manifest
    # for as many assets as we can!
    reversible do |direction|
      direction.up do
        Net::HTTP.start("images.neopets.com", 443, use_ssl: true) do |http|
          SwfAsset.find_each do |swf_asset|
            begin
              manifest_url = infer_manifest_url(http, swf_asset.url)
            rescue StandardError => error
              Rails.logger.warn "Could not infer manifest URL for #{swf_asset.id}, skipping: #{error.message}"
              next
            end

            Rails.logger.info "#{swf_asset.id}: #{manifest_url}"
            swf_asset.manifest_url = manifest_url
            swf_asset.save!
          end
        end
      end
    end
  end

  SWF_URL_PATTERN = %r{^(?:https?:)?//images\.neopets\.com/cp/(bio|items)/swf/(.+?)_([a-z0-9]+)\.swf$}
  def infer_manifest_url(http, swf_url)
    url_match = swf_url.match(SWF_URL_PATTERN)
    raise ArgumentError, "not a valid SWF URL: #{swf_url}" if url_match.nil?
    
    # Build the potential manifest URLs, from the two structures we know of.
    type, folders, hash_str = url_match.captures
    potential_manifest_urls = [
      "https://images.neopets.com/cp/#{type}/data/#{folders}/manifest.json",
      "https://images.neopets.com/cp/#{type}/data/#{folders}_#{hash_str}/manifest.json",
    ]

    # Send a HEAD request to test each manifest URL, without downloading its
    # content. If it succeeds, we're done!
    potential_manifest_urls.each do |potential_manifest_url|
      res = http.head potential_manifest_url
      if res.is_a? Net::HTTPOK
        return potential_manifest_url 
      elsif res.is_a? Net::HTTPNotFound
        next
      else
        raise "unexpected manifest response code: #{res.code}"
      end
    end

    # Otherwise, there's no valid manifest URL.
    raise "none of the common manifest URL patterns returned HTTP 200"
  end
end
