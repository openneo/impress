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

  describe "GET #index for another user's lists" do
    let(:trading) { ClosetVisibility[:trading].id }
    let(:public_vis) { ClosetVisibility[:public].id }

    let(:their_wishlist) do
      other_user.closet_lists.create!(name: "Wants", hangers_owned: false,
        visibility: trading)
    end
    let(:their_trades) do
      other_user.closet_lists.create!(name: "Trades", hangers_owned: true,
        visibility: trading)
    end

    let(:my_trades) do
      user.closet_lists.create!(name: "UFT", hangers_owned: true,
        visibility: trading)
    end
    let(:my_keepers) do
      user.closet_lists.create!(name: "Keepers", hangers_owned: true,
        visibility: public_vis)
    end
    let(:my_seeking) do
      user.closet_lists.create!(name: "Seeking", hangers_owned: false,
        visibility: trading)
    end
    let(:my_dreams) do
      user.closet_lists.create!(name: "Dreams", hangers_owned: false,
        visibility: public_vis)
    end

    let(:traded_item) { create_item("Traded") }
    let(:kept_item) { create_item("Kept") }
    let(:kept_and_traded_item) { create_item("Kept and Traded") }
    let(:sought_item) { create_item("Sought") }
    let(:dreamt_item) { create_item("Dreamt") }

    before do
      Fundraising::Campaign.create!(active: true, goal: 100,
        description: "Test")

      [traded_item, kept_item, kept_and_traded_item].each do |item|
        other_user.closet_hangers.create!(item:, owned: false, quantity: 1,
          list: their_wishlist)
      end
      [sought_item, dreamt_item].each do |item|
        other_user.closet_hangers.create!(item:, owned: true, quantity: 1,
          list: their_trades)
      end

      user.closet_hangers.create!(item: traded_item, owned: true, quantity: 1,
        list: my_trades)
      user.closet_hangers.create!(item: kept_item, owned: true, quantity: 1,
        list: my_keepers)
      user.closet_hangers.create!(item: kept_and_traded_item, owned: true,
        quantity: 1, list: my_keepers)
      user.closet_hangers.create!(item: kept_and_traded_item, owned: true,
        quantity: 1, list: my_trades)
      user.closet_hangers.create!(item: sought_item, owned: false, quantity: 1,
        list: my_seeking)
      user.closet_hangers.create!(item: dreamt_item, owned: false, quantity: 1,
        list: my_dreams)
    end

    it "lists which of your lists each match is in, and if they're trading" do
      get :index, params: {user_id: other_user.id}

      matches = assigns(:trade_matches)
      expect(matches[:owns]).to eq(
        traded_item.id => [{name: "UFT", trading: true}],
        kept_item.id => [{name: "Keepers", trading: false}],
        # Trading lists come first.
        kept_and_traded_item.id => [
          {name: "UFT", trading: true},
          {name: "Keepers", trading: false},
        ],
      )
      expect(matches[:wants]).to eq(
        sought_item.id => [{name: "Seeking", trading: true}],
        dreamt_item.id => [{name: "Dreams", trading: false}],
      )
    end

    it "doesn't include anything for signed-out viewers" do
      sign_out :auth_user
      get :index, params: {user_id: other_user.id}
      expect(assigns(:trade_matches)).to be_nil
    end

    context "with your unlisted items" do
      let(:unlisted_item) { create_item("Unlisted") }

      before do
        other_user.closet_hangers.create!(item: unlisted_item, owned: false,
          quantity: 1, list: their_wishlist)
        user.closet_hangers.create!(item: unlisted_item, owned: true,
          quantity: 1)
      end

      it "counts them as trading if your owned items are trading" do
        user.update!(owned_closet_hangers_visibility: trading)
        get :index, params: {user_id: other_user.id}
        expect(assigns(:trade_matches)[:owns][unlisted_item.id]).
          to eq [{name: nil, trading: true}]
      end

      it "doesn't count them as trading if your owned items are just public" do
        user.update!(owned_closet_hangers_visibility: public_vis)
        get :index, params: {user_id: other_user.id}
        expect(assigns(:trade_matches)[:owns][unlisted_item.id]).
          to eq [{name: nil, trading: false}]
      end
    end
  end
end
