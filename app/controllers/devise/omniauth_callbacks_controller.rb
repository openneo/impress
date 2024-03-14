class Devise::OmniauthCallbacksController < ApplicationController
	# See https://github.com/omniauth/omniauth/wiki/FAQ#rails-session-is-clobbered-after-callback-on-developer-strategy
	skip_before_action :verify_authenticity_token, only: :developer

	def developer
		render plain: "Success!"
	end
end
