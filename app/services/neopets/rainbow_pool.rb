# Neopets::RainbowPool loads data from the Rainbow Pool's AJAX endpoint, which
# backs the "All Pets" and "Brushes" pages at neopets.com/pool/.
#
# All three modes POST to the same URL, and respond with JSON like
# `{"success": true, ...}`:
#
# - `AllPets`: every species, as `speciesList: [{id, name, image}]`, and every
#   color, as `colors: [{id, name}]`. (The names are usually right, but not
#   always: Elderlygirl is "ElderlyGir"!)
# - `getAllPetColors` (with `f_species_id`): every color that species can be,
#   as `items: [{id, name, image}]`, where `id` is the color ID and `image` is a
#   pets.neopets.com URL whose path includes the basic image hash.
# - `Brushes`: every paint brush, as `brushes: [{oii, colorId, name, image}]`.
#
# We parse strictly: if the response doesn't look the way we expect, we raise,
# rather than returning nothing. (Neopets redesigned the Rainbow Pool once
# already, and our old scraper quietly started finding nothing.)
#
# We track our Neologin cookie's health (see `Neologin.with_tracking`) around
# the request itself, but not the parsing: a format change isn't the cookie's
# fault, and counting it as a cookie failure would send a misleading "rotate
# the cookie" alert, and use up the alert for when it really expires.
module Neopets::RainbowPool
	URL = "https://www.neopets.com/np-templates/ajax/pool/pool.php"

	class UnexpectedResponseFormat < RuntimeError; end

	# Returns `{species: [{id:, name:}, ...], colors: [{id:, name:}, ...]}`.
	def self.load_all_pets
		data = request(mode: "AllPets")
		species = list(data, :speciesList).map do |s|
			{id: integer(s, :id), name: string(s, :name)}
		end
		colors = list(data, :colors).map do |c|
			{id: integer(c, :id), name: string(c, :name)}
		end
		if species.empty? || colors.empty?
			raise UnexpectedResponseFormat,
				"Rainbow Pool listed #{species.size} species and #{colors.size} colors"
		end
		{species:, colors:}
	end

	# Returns `[{color_id:, name:, image_hash:}, ...]`.
	def self.load_colors_for_species(species_id)
		data = request(mode: "getAllPetColors", f_species_id: species_id)
		colors = list(data, :items)
		if colors.empty?
			raise UnexpectedResponseFormat,
				"Rainbow Pool listed no colors for species #{species_id}"
		end

		colors.map do |color|
			{
				color_id: integer(color, :id),
				name: string(color, :name),
				image_hash: image_hash_from_url(string(color, :image)),
			}
		end
	end

	# Returns `[{item_id:, color_id:, name:, image_url:}, ...]`.
	def self.load_brushes
		data = request(mode: "Brushes")
		brushes = list(data, :brushes)
		if brushes.empty?
			raise UnexpectedResponseFormat, "Rainbow Pool listed no paint brushes"
		end

		brushes.map do |brush|
			{
				item_id: integer(brush, :oii),
				color_id: integer(brush, :colorId),
				name: string(brush, :name),
				image_url: string(brush, :image),
			}
		end
	end

	# Pull the image hash out of a URL like
	# `//pets.neopets.com/cp/g3m4n4sf/1/7.png`.
	IMAGE_URL_PATTERN = %r{\A(?:https?:)?//pets\.neopets\.com/cp/([0-9a-z]+)/\d+/\d+\.png\z}
	def self.image_hash_from_url(url)
		match = url.match(IMAGE_URL_PATTERN)
		if match.nil?
			raise UnexpectedResponseFormat,
				"Rainbow Pool image URL isn't in the format we expect: #{url.inspect}"
		end
		match[1]
	end

	# Helpers for the above:

	def self.request(params)
		body = Neologin.with_tracking { fetch(params) }
		parse(body, params)
	end

	# Make the request, and return the response body. Raises if the request
	# fails, or if Neopets rejects our cookie.
	def self.fetch(params)
		Sync do
			Neologin.authed_post(
				URL,
				[
					["Content-Type", "application/x-www-form-urlencoded"],
					["X-Requested-With", "XMLHttpRequest"],
				],
				params.to_query,
			) do |response|
				# A redirect to the login page means our cookie isn't authenticated.
				if response.status.in?(300..399) &&
						response.headers["location"].to_s.include?("login")
					raise Neologin::CookieRejected,
						"Neopets redirected our Rainbow Pool request to the login page"
				end

				if response.status != 200
					raise UnexpectedResponseFormat,
						"expected status 200 but got #{response.status} " +
						"(#{URL}, #{params.inspect})"
				end

				body = response.read
				check_login_error!(body)
				body
			end
		end
	end

	# Neopets' AJAX endpoints respond to a bad cookie with an error like
	# `{"error":true,"errType":"login","errMsg":"…"}`.
	def self.check_login_error!(body)
		data = JSON.parse(body) rescue nil
		if data.is_a?(Hash) && data["errType"] == "login"
			raise Neologin::CookieRejected,
				"Neopets rejected our neologin cookie: #{data["errMsg"]}"
		end
	end

	def self.parse(body, params)
		data = begin
			JSON.parse(body)
		rescue JSON::ParserError
			raise UnexpectedResponseFormat,
				"Rainbow Pool response wasn't JSON (#{params.inspect}): " +
				body.to_s.truncate(200).inspect
		end

		unless data.is_a?(Hash)
			raise UnexpectedResponseFormat,
				"expected Rainbow Pool response to be an object, got #{data.class}"
		end
		data = data.deep_symbolize_keys

		if data[:success] != true
			raise UnexpectedResponseFormat,
				"Rainbow Pool response wasn't successful (#{params.inspect}): " +
				body.to_s.truncate(200).inspect
		end

		data
	end

	def self.list(data, key)
		value = data[key]
		unless value.is_a?(Array)
			raise UnexpectedResponseFormat,
				"expected #{key} in Rainbow Pool response to be a list, " +
				"got #{value.class}"
		end
		value.each do |entry|
			unless entry.is_a?(Hash)
				raise UnexpectedResponseFormat,
					"expected entries in #{key} to be objects, got #{entry.class}"
			end
		end
		value
	end

	def self.integer(hash, key)
		value = hash[key]
		return value if value.is_a?(Integer)
		return value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)
		raise UnexpectedResponseFormat,
			"expected #{key} to be an integer, got #{value.inspect}"
	end

	def self.string(hash, key)
		value = hash[key]
		return value if value.is_a?(String) && value.present?
		raise UnexpectedResponseFormat,
			"expected #{key} to be a non-empty string, got #{value.inspect}"
	end
end
