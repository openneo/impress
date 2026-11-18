require_relative '../rails_helper'
require_relative '../support/account_data_helpers'

RSpec.describe ClosetHangersController, :account_data, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:auth_user) { create_account("Alice") }
  let(:user) { auth_user.user }
  let(:other_user) { create_account("Bob").user }
  let(:item) { create_item("Hat") }
  let(:own_list) { user.closet_lists.create!(name: "Mine", hangers_owned: true) }
  let(:others_list) { other_user.closet_lists.create!(name: "Theirs", hangers_owned: true) }
  let!(:hanger) { user.closet_hangers.create!(item: item, owned: true, quantity: 1, list: own_list) }

  before do
    # Rails lazy-loads routes in tests, but Devise only sets up its session
    # serialization once `devise_for` runs, which `sign_in` depends on.
    Rails.application.reload_routes_unless_loaded
    @request.env["devise.mapping"] = Devise.mappings[:auth_user]
    sign_in auth_user, scope: :auth_user
  end

  describe "PUT #update with ids (bulk move)" do
    context "when a hanger fails validation" do
      # Sent the way the closet page's JS sends it.
      def bulk_move
        request.headers["X-Requested-With"] = "XMLHttpRequest"
        request.headers["Accept"] = "*/*"
        put :update, params: {
          user_id: user.id,
          ids: [hanger.id],
          list_id: others_list.id,
          return_to: "/user/#{user.id}/closet",
        }
      end

      it "redirects back with a flash alert explaining why" do
        bulk_move

        expect(response).to redirect_to("/user/#{user.id}/closet")
        expect(flash[:alert]).to eq(
          "We couldn't move the Hat, so none of the selected items were " +
          "moved: List must belong to you")
      end

      it "leaves the hanger where it was" do
        bulk_move

        expect(response).to be_redirect
        expect(hanger.reload.list).to eq own_list
      end
    end

    context "when a later hanger fails validation after earlier ones moved" do
      let(:to_list) { user.closet_lists.create!(name: "To", hangers_owned: true) }
      # Moving `hanger` into `to_list` merges this one into it, and destroys it.
      let!(:conflicting_hanger) { user.closet_hangers.create!(item: item, owned: true, quantity: 2, list: to_list) }
      let!(:bad_hanger) do
        user.closet_hangers.create!(item: create_item("Wig"), owned: true, quantity: 1, list: own_list).
          tap { |h| h.update_column(:quantity, 0) }
      end

      it "rolls back the whole move, as the alert promises" do
        put :update, params: {
          user_id: user.id,
          ids: [hanger.id, bad_hanger.id],
          list_id: to_list.id,
          return_to: "/user/#{user.id}/closet",
        }

        expect(response).to redirect_to("/user/#{user.id}/closet")
        expect(flash[:alert]).to start_with("We couldn't move the Wig")
        expect(hanger.reload.list).to eq own_list
        expect(conflicting_hanger.reload.quantity).to eq 2
      end
    end
  end
end
