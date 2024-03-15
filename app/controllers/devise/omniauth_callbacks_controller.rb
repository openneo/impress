class Devise::OmniauthCallbacksController < ApplicationController
	def neopass
		render plain: request.env["omniauth.auth"].uid
	end

	def failure
		render plain: "Failure"
	end
end
