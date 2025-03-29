class SwfAssetsController < ApplicationController
	# We're very careful with what content is allowed to load. This is because
	# asset movies run arbitrary JS, and, while we generally trust content from
	# Neopets.com, let's not be *allowing* movie JS to do whatever it wants! This
	# is a good default security stance, even if we don't foresee an attack.
	content_security_policy do |policy|
		policy.sandbox "allow-scripts"
		policy.default_src "none"

		policy.img_src -> {
			src_list(
				helpers.image_url("favicon.png"),
				@swf_asset.image_url,
				*@swf_asset.canvas_movie_sprite_urls,

				# For images, `images.neopets.com` is a generally safe host to load
				# from (shouldn't be a vulnerable site or exfiltration vector), and
				# doing this can help make this header a *lot* shorter, which helps
				# our nginx reverse proxy (and probably some clients) handle it. (For
				# example, see asset `667993` for "Engulfed in Flames Effect".)
				origins: ["https://images.neopets.com"],
			)
		}

		policy.script_src -> {
			src_list(
				helpers.javascript_url("easeljs.min"),
				helpers.javascript_url("tweenjs.min"),
				helpers.javascript_url("swf_assets/show"),
				@swf_asset.canvas_movie_library_url,
			)
		}

		policy.style_src -> {
			src_list(
				helpers.stylesheet_url("swf_assets/show"),
			)
		}
	end

	def show
		@swf_asset = SwfAsset.find params[:id]
		render layout: nil
	end

	private

	def src_list(*urls, origins: [])
		clean_urls = urls.
			# Ignore any `nil`s that might arise
			filter(&:present?).
			# Parse the URL.
			map { |url| Addressable::URI.parse(url) }.
			# Remove query strings from URLs (they're invalid in CSPs)
			each { |url| url.query = nil }.
			# For the given `origins`, remove all their specific URLs, because
			# we'll just include the entire origin anyway.
			reject { |url| origins.include?(url.origin) }.
			# Normalize the URLs. (This fixes issues like when the canonical
			# Neopets version of the URL contains plain unescaped spaces.)
			each(&:normalize!).
			# Convert the URLs back into strings.
			map(&:to_s)

		clean_urls + origins
	end
end
