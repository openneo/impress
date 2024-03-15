class Devise::OmniauthCallbacksController < ApplicationController
	rescue_from AuthUser::MissingAuthInfoError, with: :missing_auth_info
	rescue_from ActiveRecord::RecordInvalid, with: :validation_failed

	def neopass
		@auth_user = AuthUser.from_omniauth(request.env["omniauth.auth"])

		if @auth_user.previously_new_record?
			flash[:notice] =
				"Welcome to Dress to Impress, #{@auth_user.name}! We've set up a DTI " +
				"account for you. Click Settings in the top right to learn more, or " +
				"just go ahead and get started!"
		else
			flash[:notice] = "Welcome back, #{@auth_user.name}! 💖"
		end

		sign_in_and_redirect @auth_user, event: :authentication
	end

	def failure
		flash[:warning] =
			"Hrm, something went wrong in our connection to NeoPass, sorry! " +
			"Maybe wait a moment and try again?"
		redirect_to new_auth_user_session_path
	end

	def missing_auth_info(error)
		Sentry.capture_exception error
		Rails.logger.error error.full_message

		flash[:warning] =
			"Hrm, our connection with NeoPass didn't return the information we " +
			"usually expect, sorry! If this keeps happening, please email me at " +
			"matchu@openneo.net so I can help investigate!"
		redirect_to new_auth_user_session_path
	end

	def validation_failed(error)
		Sentry.capture_exception error
		Rails.logger.error error.full_message

		flash[:warning] =
			"Hrm, the connection with NeoPass worked, but we had trouble saving " +
			"your account, sorry! If this keeps happening, please email me at " +
			"matchu@openneo.net so I can help investigate!"
		redirect_to new_auth_user_session_path
	end
end
