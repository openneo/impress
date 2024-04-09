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
