require_relative '../../rails_helper'
require_relative '../../support/account_data_helpers'

RSpec.describe AuthUser::Deletion, :account_data do
  fixtures :colors, :species, :pet_types

  let(:auth_user) { create_account("doomed") }
  let(:user) { auth_user.user }
  let!(:records) { populate_account(user) }

  # Another user's data, which should be left alone.
  let(:bystander) { create_account("Bystander").user }
  let!(:bystander_records) { populate_account(bystander) }

  it "deletes the login and user records" do
    described_class.new(auth_user).call

    expect(AuthUser.where(id: auth_user.id)).not_to exist
    expect(User.where(id: user.id)).not_to exist
  end

  it "deletes the user's lists, items, outfits, connections, and contributions" do
    outfit_id = records[:outfit].id

    described_class.new(auth_user).call

    expect(ClosetList.where(user_id: user.id)).not_to exist
    expect(ClosetHanger.where(user_id: user.id)).not_to exist
    expect(Outfit.where(user_id: user.id)).not_to exist
    expect(ItemOutfitRelationship.where(outfit_id:)).not_to exist
    expect(NeopetsConnection.where(user_id: user.id)).not_to exist
    expect(Contribution.where(user_id: user.id)).not_to exist
  end

  it "keeps the contributed data itself" do
    described_class.new(auth_user).call

    expect(Item.where(id: records[:hat].id)).to exist
  end

  it "keeps donation records, but detaches them from the user and outfit" do
    described_class.new(auth_user).call

    donation = records[:donation].reload
    expect(donation.user_id).to be_nil
    expect(donation.donor_name).to be_nil
    expect(donation.donor_email).to be_nil
    expect(donation.amount).to eq 500
    expect(records[:feature].reload.outfit_id).to be_nil
  end

  it "deletes legacy login cookies" do
    connection = ApplicationRecord.connection
    insert = "INSERT INTO login_cookies (user_id, series, token) VALUES (%d, 1, 2)"
    connection.execute(insert % user.id)
    connection.execute(insert % bystander.id)

    described_class.new(auth_user).call

    remaining = connection.select_values("SELECT user_id FROM login_cookies")
    expect(remaining).to eq [bystander.id]
  end

  it "finishes the job if a previous deletion only removed the user record" do
    User.where(id: user.id).delete_all
    auth_user.reload

    result = described_class.new(auth_user).call

    expect(result.counts).to eq({})
    expect(AuthUser.where(id: auth_user.id)).not_to exist
  end

  it "detaches NeoLogin cookies the user created" do
    cookie = NeologinCookie.create!(cookie: "abc", created_by: user)

    described_class.new(auth_user).call

    expect(cookie.reload.created_by_id).to be_nil
  end

  it "leaves other users' data alone" do
    described_class.new(auth_user).call

    expect(bystander.reload).to be_present
    expect(bystander.closet_hangers.count).to eq 2
    expect(bystander.closet_lists.count).to eq 1
    expect(bystander.outfits.count).to eq 1
    expect(bystander_records[:outfit].item_outfit_relationships.count).to eq 2
    expect(bystander.contributions.count).to eq 1
    expect(bystander.neopets_connections.count).to eq 1
    expect(bystander_records[:donation].reload.user_id).to eq bystander.id
    expect(bystander_records[:donation].donor_name).to eq "bystander"
    expect(bystander_records[:feature].reload.outfit_id).
      to eq bystander_records[:outfit].id
  end

  it "reports what it deleted" do
    result = described_class.new(auth_user).call

    expect(result.name).to eq "doomed"
    expect(result.counts).to include(closet_hangers: 2, closet_lists: 1,
      outfits: 1, item_outfit_relationships: 2, contributions: 1,
      neopets_connections: 1, users: 1, donations_detached: 1)
  end

  it "refuses to delete support staff" do
    user.update!(support_staff: true)

    expect { described_class.new(auth_user).call }.
      to raise_error(AuthUser::Deletion::NotAllowed)
    expect(AuthUser.where(id: auth_user.id)).to exist
  end

  it "rolls back the user data if deleting the login fails" do
    allow(auth_user).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

    expect { described_class.new(auth_user).call }.
      to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(User.where(id: user.id)).to exist
    expect(user.closet_hangers.count).to eq 2
    expect(records[:donation].reload.user_id).to eq user.id
  end
end
