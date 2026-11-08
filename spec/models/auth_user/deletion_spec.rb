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

  it "doesn't use IN (SELECT ...) subqueries in UPDATE or DELETE statements" do
    # MariaDB (before 11.1) can't optimize these, and scans (and locks!) the
    # whole table instead. On tiny test tables that's invisible, so we check
    # the SQL itself. See the NOTE in `AuthUser::Deletion#delete_user_data!`.
    statements = []
    callback = ->(*, payload) { statements << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      described_class.new(auth_user).call
    end

    writes = statements.grep(/\A\s*(UPDATE|DELETE)/i)
    expect(writes).not_to be_empty
    expect(writes.grep(/IN\s*\(\s*SELECT/i)).to be_empty
  end

  it "handles users with more outfits than one batch" do
    pet_state = records[:outfit].pet_state
    extra = 3.times.map do |i|
      Outfit.create!(user: user, name: "Extra #{i}", pet_state: pet_state,
        worn_items: [records[:hat]])
    end

    deletion = described_class.new(auth_user)
    allow(deletion).to receive(:in_batches_of_ids).and_wrap_original do |m, ids, &block|
      m.call(ids, batch_size: 2, &block)
    end
    result = deletion.call

    expect(result.counts[:outfits]).to eq 4
    expect(result.counts[:item_outfit_relationships]).to eq 5
    expect(Outfit.where(id: extra.map(&:id))).not_to exist
    expect(bystander.outfits.count).to eq 1
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
