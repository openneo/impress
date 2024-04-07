class NeopassConnectionsController < ApplicationController
	def destroy
		@user = load_user

		if @user.disconnect_neopass
			flash[:notice] = "Your NeoPass has been disconnected. In the future, " +
				"to log into this account, you'll need to use your password or your " +
				"recovery email. You can also connect a different NeoPass, if you'd " +
				"like."
		else
			flash[:alert] = "Whoops, there was an error disconnecting your " +
				"NeoPass from your account, sorry. If this keeps happening, let us " +
				"know!"
		end

		redirect_to edit_auth_user_registration_path
	end

	private

	def load_user
		# Well, what we *actually* do is just use `current_user`, and enforce that
		# the provided user ID matches. The user ID param is only really for REST
		# semantics and such!
		raise AccessDenied unless user_signed_in?
		raise AccessDenied unless current_user.id == params[:user_id].to_i
		current_user
	end
end
