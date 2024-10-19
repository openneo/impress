require 'rocketamf_extensions/remote_gateway'

module Neopets::CustomPets
	NEOPETS_URL_ORIGIN = ENV['NEOPETS_URL_ORIGIN'] || 'https://www.neopets.com'
	GATEWAY_URL = NEOPETS_URL_ORIGIN + '/amfphp/gateway.php'
	GATEWAY = RocketAMFExtensions::RemoteGateway.new(GATEWAY_URL)
	CUSTOM_PET_SERVICE = GATEWAY.service('CustomPetService')
	PET_SERVICE = GATEWAY.service('PetService')

	class << self
		# NOTE: Ideally pet requests shouldn't take this long, but Neopets can be
		# slow sometimes! Since we're on the Falcon server, long timeouts shouldn't
		# slow down the rest of the request queue, like it used to be in the past.
		def fetch_viewer_data(name, timeout: 10)
			request = CUSTOM_PET_SERVICE.action('getViewerData').request([name])
			send_amfphp_request(request).tap do |data|
				if data[:custom_pet][:name].blank?
					raise PetNotFound, "Pet #{name.inspect} does not exist"
				end
			end
		end

		def fetch_metadata(name, timeout: 10)
			# If this is an image hash "pet name", it has no metadata.
			return nil if name.start_with?("@")

			request = PET_SERVICE.action('getPet').request([name])
			send_amfphp_request(request).tap do |data|
				if data[:name].blank?
					raise PetNotFound, "Pet #{name.inspect} does not exist"
				end
			end
		end

		# Given a pet's name, load its image hash, for use in `pets.neopets.com`
		# image URLs. (This corresponds to its current biology and items.)
		def fetch_image_hash(name, timeout: 10)
			# If this is an image hash "pet name", just take off the `@`!
			return name[1..] if name.start_with?("@")

			metadata = fetch_metadata(name, timeout:)
			metadata[:hash]
		end

		private

		# Send an AMFPHP request, re-raising errors as `Pet::DownloadError`.
		# Return the response body as a `HashWithIndifferentAccess`.
		def send_amfphp_request(request, timeout: 10)
			begin
				response_data = request.post(timeout: timeout, headers: {
					"User-Agent" => Rails.configuration.user_agent_for_neopets,
				})
			rescue RocketAMFExtensions::RemoteGateway::AMFError => e
				raise DownloadError, e.message
			rescue RocketAMFExtensions::RemoteGateway::ConnectionError => e
				raise DownloadError, e.message, e.backtrace
			end

			HashWithIndifferentAccess.new(response_data)
		end
	end
end
