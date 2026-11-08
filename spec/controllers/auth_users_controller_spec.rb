require_relative '../rails_helper'
require_relative '../support/account_data_helpers'

RSpec.describe AuthUsersController, :account_data, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:auth_user) { create_account("Leaving") }

  before do
    # Rails lazy-loads routes in tests, but Devise only sets up its session
    # serialization once `devise_for` runs, which `sign_in` depends on.
    Rails.application.reload_routes_unless_loaded
    @request.env["devise.mapping"] = Devise.mappings[:auth_user]
  end

  describe "PUT #update, when it fails" do
    before { sign_in auth_user, scope: :auth_user }

    it "gives the view the saved account, not the unsaved changes" do
      put :update, params: {id: auth_user.id, auth_user: {name: "typedname",
        password: "newpassword", password_confirmation: "mismatch",
        current_password: "password123"}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(assigns(:auth_user).name).to eq "typedname"
      persisted = assigns(:persisted_auth_user)
      expect(persisted).to be_persisted
      expect(persisted.name).to eq "leaving"
      expect(persisted.user).to eq auth_user.user
    end
  end

  describe "GET #export" do
    it "downloads the signed-in user's data as JSON" do
      sign_in auth_user, scope: :auth_user
      get :export

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(JSON.parse(response.body)["account"]["name"]).to eq "leaving"
    end

    it "requires signing in" do
      get :export
      expect(response).to redirect_to(new_auth_user_session_path)
    end
  end

  describe "DELETE #destroy" do
    def delete_account(confirm_name: "leaving", current_password: "password123", id: auth_user.id)
      delete :destroy, params: {id:, account_deletion: {confirm_name:, current_password:}}
    end

    before { sign_in auth_user, scope: :auth_user }

    it "deletes the account and signs out, with the right name and password" do
      delete_account

      expect(AuthUser.where(id: auth_user.id)).not_to exist
      expect(response).to redirect_to(root_path)
      expect(controller.current_auth_user).to be_nil
      expect(flash[:notice]).to include("has been deleted")
    end

    it "accepts the username in a different case" do
      delete_account(confirm_name: "  LEAVING ")
      expect(AuthUser.where(id: auth_user.id)).not_to exist
    end

    it "refuses if the username doesn't match" do
      delete_account(confirm_name: "Staying")

      expect(AuthUser.where(id: auth_user.id)).to exist
      expect(response).to have_http_status(:unprocessable_content)
      expect(assigns(:deletion_error)).to include("type your username")
    end

    it "refuses if the password is wrong" do
      delete_account(current_password: "nope")

      expect(AuthUser.where(id: auth_user.id)).to exist
      expect(response).to have_http_status(:unprocessable_content)
      expect(assigns(:deletion_error)).to include("password")
    end

    it "refuses to delete someone else's account" do
      other = create_account("Other")
      delete_account(id: other.id)
      expect(response).to have_http_status(:forbidden)
      expect(AuthUser.where(id: other.id)).to exist
    end

    context "for an account without a password" do
      let(:auth_user) do
        AuthUser.create!(name: "NeoPassUser", email: "np@example.com",
          provider: "neopass", uid: "np-123", neopass_email: "np@example.com")
      end

      def set_session_authenticated_at(time)
        warden.session(:auth_user)["authenticated_at"] = time&.to_i
      end

      it "deletes the account if this session logged in recently" do
        set_session_authenticated_at 5.minutes.ago
        delete_account(confirm_name: "neopassuser", current_password: "")

        expect(AuthUser.where(id: auth_user.id)).not_to exist
      end

      it "refuses if this session logged in a while ago" do
        set_session_authenticated_at 2.hours.ago
        delete_account(confirm_name: "neopassuser", current_password: "")

        expect(AuthUser.where(id: auth_user.id)).to exist
        expect(assigns(:deletion_error)).to include("log back in")
      end

      it "refuses if a *different* session logged in recently, but not this one" do
        # e.g. the owner just logged in on their phone, but this is an old
        # session on a shared computer.
        auth_user.update!(current_sign_in_at: 1.minute.ago)
        set_session_authenticated_at 3.days.ago
        delete_account(confirm_name: "neopassuser", current_password: "")

        expect(AuthUser.where(id: auth_user.id)).to exist
        expect(assigns(:deletion_error)).to include("log back in")
      end

      it "refuses if this session has no login time recorded" do
        set_session_authenticated_at nil
        delete_account(confirm_name: "neopassuser", current_password: "")

        expect(AuthUser.where(id: auth_user.id)).to exist
        expect(assigns(:deletion_error)).to include("log back in")
      end
    end

    it "refuses to delete support staff" do
      auth_user.user.update!(support_staff: true)
      delete_account

      expect(AuthUser.where(id: auth_user.id)).to exist
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
