class Devise::OmniauthCallbacksController < ApplicationController
	def neopass
		render plain: "Success!"
	end

	def failure
		render plain: "Failure"
	end
end
