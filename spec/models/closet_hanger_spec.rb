require_relative '../rails_helper'

RSpec.describe ClosetHanger do
  let(:user) { create_user('Alice') }
  let(:item) { create_item }
  let(:owned_list) { user.closet_lists.create!(name: 'Owned', hangers_owned: true) }
  let(:wanted_list) { user.closet_lists.create!(name: 'Wanted', hangers_owned: false) }

  describe 'moving to another list' do
    it 'merges into an existing hanger in a list of the same ownership' do
      other_owned_list = user.closet_lists.create!(name: 'Owned 2', hangers_owned: true)
      existing = user.closet_hangers.create!(item: item, list: owned_list, quantity: 2)
      moving = user.closet_hangers.create!(item: item, list: other_owned_list, quantity: 3)

      moving.possibly_null_list_id = owned_list.id
      moving.save!

      expect(ClosetHanger.exists?(existing.id)).to be false
      expect(moving.reload.quantity).to eq 5
      expect(moving.list).to eq owned_list
    end

    it 'merges into an existing hanger when moving from a wanted list to an owned list' do
      existing = user.closet_hangers.create!(item: item, list: owned_list, quantity: 2)
      moving = user.closet_hangers.create!(item: item, list: wanted_list, quantity: 3)
      expect(moving).not_to be_owned

      moving.possibly_null_list_id = owned_list.id
      moving.save!

      expect(ClosetHanger.exists?(existing.id)).to be false
      expect(moving.reload).to be_owned
      expect(moving.quantity).to eq 5
      expect(moving.list).to eq owned_list
    end

    it 'merges into an existing hanger when moving from an owned list to a wanted list' do
      existing = user.closet_hangers.create!(item: item, list: wanted_list, quantity: 1)
      moving = user.closet_hangers.create!(item: item, list: owned_list, quantity: 1)

      moving.possibly_null_list_id = wanted_list.id
      moving.save!

      expect(ClosetHanger.exists?(existing.id)).to be false
      expect(moving.reload).not_to be_owned
      expect(moving.quantity).to eq 2
    end
  end

  def create_user(name)
    auth_user = AuthUser.create!(
      name: name,
      email: "#{name.downcase}@example.com",
      password: 'password123',
      password_confirmation: 'password123'
    )
    User.create!(name: name, remote_id: auth_user.id, auth_server_id: 1)
  end

  def create_item
    Item.create!(
      name: "Test Item #{SecureRandom.hex(4)}",
      description: "Test item",
      thumbnail_url: "http://example.com/thumb.png",
      rarity: "",
      price: 0,
      zones_restrict: ""
    )
  end
end
