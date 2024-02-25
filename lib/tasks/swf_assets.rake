require 'async/barrier'
require 'async/http/internet/instance'

namespace :swf_assets do
	# NOTE: I'm not sure how these duplicate records enter our database, probably
	# a bug in the modeling code somewhere? For now, let's just remove them, and
	# be ready to run it again if needed!
	# NOTE: Run with DRY_RUN=1 to see what it would do first!
	desc "Remove duplicate SwfAsset records"
	task remove_duplicates: [:environment] do
		duplicate_groups = SwfAsset.group(:type, :remote_id).
			having("COUNT(*) > 1").
			pluck(:type, :remote_id, Arel.sql("GROUP_CONCAT(id ORDER BY id ASC)"))

		total = duplicate_groups.size
		puts "Found #{total} groups of duplicate records"

		SwfAsset.transaction do
			duplicate_groups.each_with_index do |(type, remote_id, ids_str), index|
				ids = ids_str.split(",")
				duplicate_ids = ids[1..]
				duplicate_records = SwfAsset.find(duplicate_ids)

				if ENV["DRY_RUN"]
					puts "[#{index + 1}/#{total}] #{type}/#{remote_id}: " + 
						"Would delete #{duplicate_records.size} records " +
						"(#{duplicate_records.map(&:id).join(", ")})"
				else
					puts "[#{index + 1}/#{total}] #{type}/#{remote_id}: " + 
						"Deleting #{duplicate_records.size} records " +
						"(#{duplicate_records.map(&:id).join(", ")})"
					duplicate_records.each(&:destroy)
				end
			end
		end
	end

	namespace :manifests do
		desc "Save all known manifests to the Neopets Media Archive"
		task load: [:environment] do
			# Log errors to STDOUT, but we don't need the info messages about
			# successful saves.
			Rails.logger = Logger.new(STDOUT, level: :error)

			# Find all the manifests with known URLs. (We don't have a database
			# filter for "do we already have the manifest downloaded", but that's
			# okay, the preload method will quickly check that for us!)
			swf_assets = SwfAsset.where.not(manifest_url: nil)
			total_count = swf_assets.count
			puts "Found #{total_count} assets with manifests"

			# For each batch of 1000 assets, load their manifests concurrently.
			# Wrap everything in a top-level sync, so keyboard interrupts will
			# propagate all the way up to here, instead of just cancelling the
			# current batch.
			Sync do
				saved_count = 0
				swf_assets.find_in_batches(batch_size: 1000) do |swf_assets|
					# NOTE: Loading the manifests can both write to the filesystem *and*
					# to the database, because we track timestamp and status in the db!
					SwfAsset.transaction do
						SwfAsset.preload_manifests(swf_assets)
					end
					saved_count += swf_assets.size
					puts "Loaded #{saved_count} of #{total_count} manifests"
				end
			end
		end

		desc "Backfill manifest_url for SwfAsset models"
		task urls: [:environment] do
			timeout = ENV.fetch("TIMEOUT", "5").to_i

			assets = SwfAsset.where(manifest_url: nil)
			count = assets.count
			puts "Found #{count} assets without manifests"

			Sync do
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
								task.with_timeout(timeout) do
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
