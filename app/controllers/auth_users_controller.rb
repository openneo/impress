class AuthUsersController < ApplicationController
	before_action :authenticate_user!, except: [:new, :create]

	def create
		@auth_user = AuthUser.create(auth_user_params)

		if @auth_user.persisted?
			sign_in :auth_user, @auth_user
			flash[:notice] = "Welcome to Dress to Impress, #{@auth_user.name}! 💖"
			redirect_to root_path
		else
			render action: :new, status: :unprocessable_entity
		end
	end

	def edit
		# For the edit form, the auth user *is* the persisted auth user.
		@persisted_auth_user = current_auth_user
		@auth_user = @persisted_auth_user
	end

	def export
		export = AccountExport.new(current_auth_user)
		send_data export.to_json, filename: export.filename,
			type: "application/json", disposition: "attachment"
	end

	def destroy
		@auth_user = load_auth_user
		@persisted_auth_user = @auth_user

		@deletion_error = deletion_error_for(@auth_user)
		if @deletion_error
			render action: :edit, status: :unprocessable_entity
			return
		end

		result = AccountDeletion.new(@auth_user).call
		sign_out :auth_user
		flash[:notice] = "Your account \"#{result.name}\" has been deleted. " +
			"Thank you for spending time with us, and take care! 💜"
		redirect_to root_path
	rescue AccountDeletion::NotAllowed => error
		@deletion_error = error.message
		render action: :edit, status: :unprocessable_entity
	end

	def new
		@auth_user = AuthUser.new
	end

	def update
		# When updating, we hold onto the original `@persisted_auth_user`, then
		# make our changes to `@auth_user`. That way, the form can check the *live*
		# value of `uses_password?` to decide whether to show the "Current
		# password" field, instead of getting thrown off if the password changed
		# but the record didn't get saved.
		#
		# HACK: Is there a way to get the kind of copy we want for real? `dup`
		#       actually returns a *new* unsaved record with the same attributes.
		@auth_user = load_auth_user
		@persisted_auth_user = @auth_user.dup

		if @auth_user.update_with_password(auth_user_params)
			# NOTE: Changing the password will sign you out, so make sure we stay
			# signed in!
			bypass_sign_in @auth_user, scope: :auth_user

			flash[:notice] = "Settings successfully saved."
			redirect_to action: :edit
		else
			render action: :edit, status: :unprocessable_entity
		end
	end

	private

	# How long ago you must have logged in, to delete an account without a
	# password (e.g. NeoPass-only accounts).
	RECENT_SIGN_IN_WINDOW = 30.minutes

	# Returns an error message if this deletion request isn't confirmed well
	# enough, or nil if it's okay to proceed.
	def deletion_error_for(auth_user)
		confirm_name = params.dig(:account_deletion, :confirm_name).to_s.strip
		if confirm_name.casecmp(auth_user.name) != 0
			return "To delete your account, type your username " +
				"\"#{auth_user.name}\" exactly as shown."
		end

		if auth_user.uses_password?
			password = params.dig(:account_deletion, :current_password).to_s
			unless auth_user.valid_password?(password)
				return "That password doesn't match. Please enter your current " +
					"password to confirm."
			end
		elsif !signed_in_recently?(auth_user)
			return "For safety, please log out and log back in with NeoPass, " +
				"then try again within #{RECENT_SIGN_IN_WINDOW.inspect}."
		end

		nil
	end

	def signed_in_recently?(auth_user)
		auth_user.current_sign_in_at.present? &&
			auth_user.current_sign_in_at > RECENT_SIGN_IN_WINDOW.ago
	end

	def auth_user_params
		params.require(:auth_user).permit(:name, :email, :password,
			:password_confirmation, :current_password)
	end

	def load_auth_user
		# Well, what we *actually* do is just use `current_auth_user`, and enforce
		# that the provided user ID matches. The user ID param is only really for
		# REST semantics and such!
		raise AccessDenied unless auth_user_signed_in?
		raise AccessDenied unless current_auth_user.id == params[:id].to_i
		current_auth_user
	end
end
