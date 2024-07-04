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
			)
		}

		policy.script_src_elem -> {
			src_list(
				helpers.javascript_url("lib/easeljs.min"),
				helpers.javascript_url("lib/tweenjs.min"),
				helpers.javascript_url("swf_assets/show"),
				@swf_asset.canvas_movie_library_url,
			)
		}

		policy.style_src_elem -> {
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

	def src_list(*urls)
		urls.filter(&:present?).map { |url| url.sub(/\?.*\z/, "") }.join(" ")
	end
end
