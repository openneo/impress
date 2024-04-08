class Devise::OmniauthCallbacksController < ApplicationController
	rescue_from AuthUser::AuthAlreadyConnected, with: :auth_already_connected
	rescue_from AuthUser::MissingAuthInfoError, with: :missing_auth_info
	rescue_from ActiveRecord::RecordInvalid, with: :validation_failed

	def neopass
		case intent_param
		when "login"
			sign_in_with_neopass
		when "connect"
			connect_with_neopass
		else
			flash[:alert] = "Hrm, the NeoPass form you used was missing some " +
				"\"intent\" information. That's surprising! Maybe try again?"
			redirect_to root_path
		end
	end

	def failure
		flash[:warning] =
			"Hrm, something went wrong in our connection to NeoPass, sorry! " +
			"Maybe wait a moment and try again?"
		redirect_to new_auth_user_session_path
	end

	private

	def sign_in_with_neopass
		@auth_user = AuthUser.from_omniauth(request.env["omniauth.auth"])

		if @auth_user.previously_new_record?
			flash[:notice] =
				"Welcome to Dress to Impress! We've set up a DTI account for you, " +
				"attached to your NeoPass. Click Settings in the top right to learn " +
				"more, or just go ahead and get started!"
		else
			flash[:notice] =
				"Welcome back, #{@auth_user.name}! You are now logged in. 💖"
		end

		sign_in_and_redirect @auth_user, event: :authentication
	end

	def connect_with_neopass
		raise AccessDenied unless auth_user_signed_in?

		current_auth_user.connect_omniauth!(request.env["omniauth.auth"])

		flash[:notice] = "We've successfully connected your NeoPass!"
		redirect_to edit_auth_user_path
	end

	def auth_already_connected(error)
		flash[:alert] = "This NeoPass is already connected to another account. " +
			"You'll need to log out of this account, log in with that NeoPass, " +
			"then disconnect it from the other account."
		redirect_to return_path
	end

	def missing_auth_info(error)
		Sentry.capture_exception error
		Rails.logger.error error.full_message

		flash[:warning] =
			"Hrm, our connection with NeoPass didn't return the information we " +
			"usually expect, sorry! If this keeps happening, please email me at " +
			"matchu@openneo.net so I can help investigate!"
		redirect_to return_path
	end

	def validation_failed(error)
		Sentry.capture_exception error
		Rails.logger.error error.full_message

		flash[:warning] =
			"Hrm, the connection with NeoPass worked, but we had trouble saving " +
			"your account, sorry! If this keeps happening, please email me at " +
			"matchu@openneo.net so I can help investigate!"
		redirect_to return_path
	end

	def intent_param
		request.env['omniauth.params']["intent"]
	end

	def return_path
		case intent_param
		when "login"
			new_auth_user_session_path
		when "connect"
			edit_auth_user_path
		else
			root_path
		end
	end
end
