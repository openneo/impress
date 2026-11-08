require_relative '../rails_helper'
require_relative '../support/account_data_helpers'

RSpec.describe AccountExport, :account_data do
  fixtures :colors, :species, :pet_types

  let(:auth_user) { create_account("Exporter") }
  let(:user) { auth_user.user }
  let!(:records) { populate_account(user) }
  let!(:bystander_records) { populate_account(create_account("Other").user) }

  subject(:export) { JSON.parse(described_class.new(auth_user).to_json) }

  it "includes account info, but no credentials" do
    expect(export["account"]).to include("name" => "exporter",
      "email" => "exporter@example.com", "uses_password" => true)

    json = described_class.new(auth_user).to_json
    expect(json).not_to include(auth_user.encrypted_password)
    expect(export["account"].keys).not_to include("encrypted_password",
      "password_salt", "reset_password_token", "remember_created_at")
  end

  it "includes item lists and items, with names" do
    expect(export["item_lists"]).to contain_exactly(
      a_hash_including("name" => "Trading", "kind" => "owned",
        "visibility" => "public"))
    expect(export["items"]).to contain_exactly(
      a_hash_including("item_name" => "exporter's Hat", "kind" => "owned",
        "list_name" => "Trading", "quantity" => 2),
      a_hash_including("item_name" => "exporter's Background",
        "kind" => "wanted", "list_name" => nil))
  end

  it "lists an item once per list it's in, each with its own quantity" do
    keep = user.closet_lists.create!(name: "Keep", hangers_owned: true)
    user.closet_hangers.create!(item: records[:hat], owned: true, list: keep,
      quantity: 1)

    hat_entries = export["items"].select { |i| i["item_id"] == records[:hat].id }
    expect(hat_entries).to contain_exactly(
      a_hash_including("list_name" => "Trading", "quantity" => 2),
      a_hash_including("list_name" => "Keep", "quantity" => 1))
  end

  it "includes outfits, with their pet and items" do
    expect(export["outfits"]).to contain_exactly(a_hash_including(
      "name" => "Spooky",
      "url" => "https://impress.openneo.net/outfits/#{records[:outfit].id}",
      "species" => "acara", "color" => "blue", "pose" => "HAPPY_FEM",
      "worn_items" => [{"id" => records[:hat].id, "name" => "exporter's Hat"}],
      "closeted_items" => [
        {"id" => records[:bg].id, "name" => "exporter's Background"}]))
  end

  it "includes contributions, connections, and donations" do
    expect(export["contributions"]).to contain_exactly(a_hash_including(
      "contributed_type" => "Item", "contributed_id" => records[:hat].id))
    expect(export["neopets_connections"]).to contain_exactly(
      a_hash_including("neopets_username" => "exporter_np"))
    expect(export["donations"]).to contain_exactly(
      a_hash_including("amount_in_cents" => 500,
        "featured_outfit_ids" => [records[:outfit].id]))
  end

  it "still exports the login info if the user record is missing" do
    User.where(id: user.id).delete_all
    auth_user.reload

    expect(export["account"]["name"]).to eq "exporter"
    expect(export["profile"]).to be_nil
    expect(export["items"]).to eq []
    expect(export["outfits"]).to eq []
  end

  it "doesn't include other users' data" do
    json = described_class.new(auth_user).to_json
    # (Usernames are stored lowercase, so that's what the helpers use.)
    expect(json).to include("exporter's Hat")
    expect(json).not_to include("other's Hat")
    expect(json).not_to include("other_np")
    expect(JSON.parse(json)["outfits"].map { |o| o["id"] }).
      not_to include(bystander_records[:outfit].id)
  end
end
