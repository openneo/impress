require "async/http/internet/instance"

# While most of our NeoPass logic is built into Devise -> OmniAuth -> OIDC
# OmniAuth plugin, NeoPass also offers some supplemental APIs that we use here.
module NeoPass
	# Share a pool of persistent connections, rather than reconnecting on
	# each request. (This library does that automatically!)
	INTERNET = Async::HTTP::Internet.instance

	def self.load_main_neopets_username(access_token)
		linkages = load_linkages(access_token)

		begin
			# Get the Neopets.com linkages, sorted with your "main" account to the
			# front. (In theory, if there are any Neopets.com linkages, then one
			# should be main—but let's be resilient and be prepared for none of them
			# to be marked as such!)
			neopets_linkages = linkages.
				select { |l| l.fetch("client_name") == "Neopets.com" }.
				sort_by { |l| l.fetch("extra", {}).fetch("main") == true ? 0 : 1 }

			# Read the username from that linkage, if any.
			neopets_linkages.first.try { |l| l.fetch("user_identifier") }
		rescue KeyError => error
			raise UnexpectedResponseFormat,
				"missing field #{error.key} in NeoPass linkage response"
		end
	end

	private

	LINKAGE_URL = "https://oidc.neopets.com/linkage/all"
	def self.load_linkages(access_token)
		response = Sync do
			response = INTERNET.get(LINKAGE_URL, [
				["User-Agent", Rails.configuration.user_agent_for_neopets],
				["Authorization", "Bearer #{access_token}"],
			])
		end

		if response.status != 200
			raise ResponseNotOK.new(response.status),
				"expected status 200 but got #{response.status} (#{LINKAGE_URL})"
		end

		linkages_str = response.body.read

		begin
			linkages = JSON.parse(linkages_str)
		rescue JSON::ParserError
			Rails.logger.debug "Unexpected NeoPass linkage response:\n#{linkages_str}"
			raise UnexpectedResponseFormat,
				"failed to parse NeoPass linkage response as JSON"
		end

		if !linkages.is_a? Array
			Rails.logger.debug "Unexpected NeoPass linkage response:\n#{linkages_str}"
			raise UnexpectedResponseFormat,
				"NeoPass linkage response was not an array of linkages"
		end

		linkages
	end

	class ResponseNotOK < StandardError
		attr_reader :status
		def initialize(status)
			super
			@status = status
		end
	end
	class UnexpectedResponseFormat < StandardError;end
end
