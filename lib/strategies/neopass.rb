require "omniauth-oauth2"

module Strategies
	class NeoPass < OmniAuth::Strategies::OAuth2
		option :name, "neopass"

		option :client_options, {
			site: Rails.configuration.neopass_origin,
			authorize_url: "/oauth2/auth",
			token_url: "/oauth2/token",
		}
	end
end
