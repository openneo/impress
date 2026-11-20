require_relative '../rails_helper'

RSpec.describe NeopetsPage::ImportTask do
  let(:user) { create_user('Alice') }

  # Gallery refs have no item IDs, so we match items by thumbnail URL.
  def gallery_page(*item_refs)
    page = NeopetsPage.new('gallery', 1, '')
    allow(page).to receive(:item_refs).and_return(item_refs)
    page
  end

  def gallery_ref(thumbnail_url, quantity: 1)
    NeopetsPage::ItemRef.new(nil, thumbnail_url, 'Some Item', quantity)
  end

  it 'imports items matched by thumbnail URL' do
    item = create_item(thumbnail_url: 'https://images.neopets.com/items/a.gif')
    page = gallery_page(gallery_ref('//images.neopets.com/items/a.gif', quantity: 3))

    results = page.build_import_task(user, 'true').save

    expect(results[:counts]).to eq(created: 1, updated: 0, unchanged: 0)
    expect(results[:unknown_item_names]).to be_empty
    expect(user.closet_hangers.find_by(item:).quantity).to eq 3
  end

  it 'imports a ref once when several items share its thumbnail URL' do
    create_item(thumbnail_url: 'https://images.neopets.com/items/shared.gif')
    create_item(thumbnail_url: 'http://images.neopets.com/items/shared.gif')
    page = gallery_page(gallery_ref('//images.neopets.com/items/shared.gif', quantity: 2))

    results = page.build_import_task(user, 'true').save

    expect(results[:counts]).to eq(created: 1, updated: 0, unchanged: 0)
    expect(results[:unknown_item_names]).to be_empty
    expect(user.closet_hangers.count).to eq 1
    expect(user.closet_hangers.first.quantity).to eq 2
  end

  it 'prefers an item the user already has when several share a thumbnail' do
    create_item(thumbnail_url: 'https://images.neopets.com/items/shared.gif')
    owned = create_item(thumbnail_url: 'http://images.neopets.com/items/shared.gif')
    user.closet_hangers.create!(item: owned, owned: true, quantity: 2)
    page = gallery_page(gallery_ref('//images.neopets.com/items/shared.gif', quantity: 2))

    results = page.build_import_task(user, 'true').save

    expect(results[:counts]).to eq(created: 0, updated: 0, unchanged: 1)
    expect(user.closet_hangers.map(&:item_id)).to eq [owned.id]
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

  def create_item(thumbnail_url:)
    Item.create!(
      name: "Test Item #{SecureRandom.hex(4)}",
      description: "Test item",
      thumbnail_url:,
      rarity: "",
      price: 0,
      zones_restrict: ""
    )
  end
end
