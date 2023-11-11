require 'async/barrier'
require 'async/http/internet/instance'

namespace :swf_assets do
	desc "Backfill manifest_url for SwfAsset models"
	task manifests: [:environment] do
		assets = SwfAsset.where(manifest_url: nil)
		count = assets.count
		puts "Found #{count} assets without manifests"

		Async do
			# Share a pool of persistent connections, rather than reconnecting on
			# each request. (This library does that automatically!)
			internet = Async::HTTP::Internet.instance

			# Load the assets in batches, then process each batch in two steps: first
			# inferring all manifest URLs in the batch, then saving all assets in the
			# batch. (This makes the update step more efficient, and it also avoids
			# simultaneous queries across the fibers, which ActiveRecord disallows!)
			#
			# We keep track of a shared index `i` here, but we only actually
			# increment it once each task is *done*, so that the numbers output in
			# the right order!
			i = 0
			assets.find_in_batches(batch_size: 1000) do |batch|
				# Create a barrier, to let us wait on all the tasks; then under it
				# create a semaphore, to limit how many tasks run at once.
				barrier = Async::Barrier.new
				semaphore = Async::Semaphore.new(100, parent: barrier)

				batch.each do |asset|
					semaphore.async do |task|
						manifest_url = nil
						begin
							task.with_timeout(5) do
								manifest_url = infer_manifest_url(asset.url, internet)
							end
						rescue StandardError => error
							i += 1
							puts "[#{i}/#{count}] ⚠️  Skipping #{asset.id}: #{error.message}"
							next
						end

						i += 1
						puts "[#{i}/#{count}] Manifest for #{asset.id}: #{manifest_url}"

						# Write, but don't yet save, the manifest URL.
						asset.manifest_url = manifest_url
					end
				end

				# Wait for all the above tasks to finish. (Then, all of the assets that
				# succeeded should have an unsaved `manifest_url` change.)
				barrier.wait

				# Save all of the assets in the batch. (We do this in a transaction not
				# for the transactional semantics, but because it's notably faster than
				# doing a commit between each query, which is what sending the queries
				# individually would effectively do!)
				begin
					SwfAsset.transaction do
						batch.each do |asset|
							begin
								asset.save!
							rescue StandardError => error
								puts "⚠️  Saving asset #{asset.id} failed: #{error.full_message}"
							end
						end
					end
				rescue StandardError => error
					puts "⚠️  Saving this batch failed: #{error.full_message}"
				end
			end
		end
	end
end

SWF_URL_PATTERN = %r{^(?:https?:)?//images\.neopets\.com/cp/(bio|items)/swf/(.+?)_([a-z0-9]+)\.swf$}
def infer_manifest_url(swf_url, internet)
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
    res = internet.head potential_manifest_url
    if res.ok?
      return potential_manifest_url 
    elsif res.status == 404
      next # Ok, this was not the manifest!
    else
      raise "unexpected manifest response code: #{res.status}"
    end
  end

  # Otherwise, there's no valid manifest URL.
  raise "all of the common manifest URL patterns returned HTTP 404"
end
