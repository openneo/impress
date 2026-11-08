# Helpers for building a user with a bit of everything, to test account export
# and deletion.
module AccountDataHelpers
  def create_account(name, password: "password123")
    AuthUser.create!(
      name: name,
      email: "#{name.downcase}@example.com",
      password: password,
      password_confirmation: password,
    )
  end

  def create_item(name)
    Item.create!(
      name: name,
      description: "Test item",
      thumbnail_url: "https://images.neopets.example/thumbnail.png",
      rarity: "Common",
      price: 100,
      zones_restrict: "",
      species_support_ids: "",
    )
  end

  # Gives the user a list, items, an outfit, a contribution, a Neopets
  # connection, and a donation. Returns a hash of the interesting records.
  def populate_account(user)
    hat = create_item("#{user.name}'s Hat")
    bg = create_item("#{user.name}'s Background")

    list = user.closet_lists.create!(name: "Trading", hangers_owned: true)
    owned = user.closet_hangers.create!(item: hat, owned: true, list: list,
      quantity: 2)
    wanted = user.closet_hangers.create!(item: bg, owned: false, quantity: 1)

    pet_state = PetState.create!(pet_type: pet_types(:blue_acara),
      pose: "HAPPY_FEM", swf_asset_ids: [0])
    outfit = Outfit.create!(user: user, name: "Spooky", pet_state: pet_state,
      worn_items: [hat], closeted_items: [bg])

    contribution = Contribution.create!(user: user, contributed: hat)
    connection = user.neopets_connections.create!(neopets_username: "#{user.name}_np")

    campaign = Fundraising::Campaign.create!(active: false, goal: 100,
      description: "Test")
    donation = Fundraising::Donation.create!(campaign: campaign, amount: 500,
      charge_id: "ch_#{SecureRandom.hex(4)}", user: user,
      donor_name: user.name, donor_email: "#{user.name}@example.com")
    feature = Fundraising::DonationFeature.create!(donation: donation,
      outfit: outfit)

    {hat:, bg:, list:, owned:, wanted:, outfit:, contribution:, connection:,
      donation:, feature:}
  end
end

RSpec.configure do |config|
  config.include AccountDataHelpers, :account_data
end
