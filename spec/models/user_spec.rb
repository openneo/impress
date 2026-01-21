require_relative '../rails_helper'

RSpec.describe User do
  describe '.top_contributors_for' do
    let!(:user1) { create_user('Alice') }
    let!(:user2) { create_user('Bob') }
    let!(:user3) { create_user('Charlie') }

    context 'with all_time timeframe' do
      it 'uses the denormalized points column' do
        user1.update!(points: 100)
        user2.update!(points: 50)
        user3.update!(points: 0)

        results = User.top_contributors_for(:all_time)
        expect(results.map(&:id)).to eq([user1.id, user2.id])
        expect(results.first.points).to eq(100)
        expect(results.second.points).to eq(50)
      end

      it 'excludes users with zero points' do
        user1.update!(points: 100)
        user2.update!(points: 0)

        results = User.top_contributors_for(:all_time)
        expect(results).not_to include(user2)
      end

      it 'orders by points descending' do
        user1.update!(points: 50)
        user2.update!(points: 100)
        user3.update!(points: 75)

        results = User.top_contributors_for(:all_time)
        expect(results.map(&:id)).to eq([user2.id, user3.id, user1.id])
      end
    end

    context 'with this_week timeframe' do
      let(:item) { create_item }

      before do
        # Create contributions from this week
        create_contribution(user1, item, 3.days.ago)  # 3 points
        create_contribution(user1, item, 2.days.ago)  # 3 points

        # Create contributions from last month (should be excluded)
        create_contribution(user2, item, 1.month.ago) # 3 points (excluded)
      end

      it 'calculates points from contributions in the last week' do
        results = User.top_contributors_for(:this_week)
        expect(results.first).to eq(user1)
        expect(results.first.period_points).to eq(6)
      end

      it 'excludes users with no recent contributions' do
        results = User.top_contributors_for(:this_week)
        expect(results).not_to include(user2)
      end

      it 'excludes contributions older than one week' do
        create_contribution(user3, item, 8.days.ago)

        results = User.top_contributors_for(:this_week)
        expect(results).not_to include(user3)
      end
    end

    context 'with this_month timeframe' do
      let(:item) { create_item }
      let(:pet_type) { create_pet_type }

      before do
        # User 1: contributions from this month
        create_contribution(user1, item, 15.days.ago)     # 3 points
        create_contribution(user1, pet_type, 20.days.ago) # 15 points

        # User 2: contributions older than one month
        create_contribution(user2, item, 35.days.ago)     # 3 points (excluded)
      end

      it 'calculates points from contributions in the last month' do
        results = User.top_contributors_for(:this_month)
        expect(results.first).to eq(user1)
        expect(results.first.period_points).to eq(18)
      end

      it 'excludes contributions older than one month' do
        results = User.top_contributors_for(:this_month)
        expect(results).not_to include(user2)
      end
    end

    context 'with this_year timeframe' do
      let(:item) { create_item }

      before do
        # User 1: contributions from this year
        create_contribution(user1, item, 3.months.ago)  # 3 points
        create_contribution(user1, item, 6.months.ago)  # 3 points

        # User 2: contributions older than one year
        create_contribution(user2, item, 13.months.ago) # 3 points (excluded)
      end

      it 'calculates points from contributions in the last year' do
        results = User.top_contributors_for(:this_year)
        expect(results.first).to eq(user1)
        expect(results.first.period_points).to eq(6)
      end

      it 'excludes contributions older than one year' do
        results = User.top_contributors_for(:this_year)
        expect(results).not_to include(user2)
      end
    end

    context 'point value calculations' do
      let(:item) { create_item }
      let(:pet_type) { create_pet_type }
      let(:alt_style) { create_alt_style }

      it 'assigns 3 points for Item contributions' do
        create_contribution(user1, item, 1.day.ago)

        results = User.top_contributors_for(:this_week)
        expect(results.first.period_points).to eq(3)
      end

      it 'assigns 15 points for PetType contributions' do
        create_contribution(user1, pet_type, 1.day.ago)

        results = User.top_contributors_for(:this_week)
        expect(results.first.period_points).to eq(15)
      end

      it 'assigns 30 points for AltStyle contributions' do
        create_contribution(user1, alt_style, 1.day.ago)

        results = User.top_contributors_for(:this_week)
        expect(results.first.period_points).to eq(30)
      end

      it 'sums multiple contribution types correctly' do
        create_contribution(user1, item, 1.day.ago)      # 3 points
        create_contribution(user1, pet_type, 2.days.ago) # 15 points
        create_contribution(user1, alt_style, 3.days.ago) # 30 points

        results = User.top_contributors_for(:this_week)
        expect(results.first.period_points).to eq(48)
      end
    end

    context 'ordering and filtering' do
      let(:item) { create_item }

      before do
        # Create various contributions
        3.times { create_contribution(user1, item, 1.day.ago) } # 9 points
        5.times { create_contribution(user2, item, 2.days.ago) } # 15 points
        2.times { create_contribution(user3, item, 3.days.ago) } # 6 points
      end

      it 'orders by period_points descending' do
        results = User.top_contributors_for(:this_week)
        expect(results.map(&:id)).to eq([user2.id, user1.id, user3.id])
      end

      it 'uses user.id as secondary sort for tied scores' do
        # Create two users with same points
        user4 = create_user('Dave')
        user5 = create_user('Eve')

        create_contribution(user4, item, 1.day.ago) # 3 points
        create_contribution(user5, item, 1.day.ago) # 3 points

        results = User.top_contributors_for(:this_week).where(id: [user4.id, user5.id])
        # Should be ordered by user.id ASC when points are tied
        expect(results.first.id).to be < results.second.id
      end

      it 'excludes users with zero contributions in period' do
        # user3 has no contributions this week
        user4 = create_user('Dave')

        results = User.top_contributors_for(:this_week)
        expect(results).not_to include(user4)
      end
    end

    context 'with invalid timeframe' do
      it 'raises ArgumentError' do
        expect { User.top_contributors_by_period(:invalid) }.
          to raise_error(ArgumentError, /Invalid timeframe/)
      end
    end
  end

  describe '#period_points' do
    let(:user) { create_user('Alice') }

    context 'when period_points attribute is set' do
      it 'returns the calculated period_points' do
        # Simulate a query that sets period_points
        user_with_period = User.select('users.*, 42 AS period_points').find(user.id)
        expect(user_with_period.period_points).to eq(42)
      end
    end

    context 'when period_points attribute is not set' do
      it 'falls back to denormalized points column' do
        user.update!(points: 100)
        expect(user.period_points).to eq(100)
      end
    end
  end

  # Helper methods
  def create_user(name)
    auth_user = AuthUser.create!(
      name: name,
      email: "#{name.downcase}@example.com",
      password: 'password123',
      password_confirmation: 'password123'
    )
    User.create!(name: name, remote_id: auth_user.id, auth_server_id: 1)
  end

  def create_contribution(user, contributed, created_at)
    Contribution.create!(
      user: user,
      contributed: contributed,
      created_at: created_at
    )
  end

  def create_item
    # Create a minimal item for testing
    Item.create!(
      name: "Test Item #{SecureRandom.hex(4)}",
      description: "Test item",
      thumbnail_url: "http://example.com/thumb.png",
      rarity: "",
      price: 0,
      zones_restrict: ""
    )
  end

  def create_swf_asset
    # Create a minimal swf_asset for testing
    zone = Zone.first || Zone.create!(id: 1, label: "Test Zone", plain_label: "Test Zone", type_id: 1)
    SwfAsset.create!(
      type: 'object',
      remote_id: SecureRandom.random_number(100000),
      url: "http://example.com/test.swf",
      zone_id: zone.id,
      body_id: 0
    )
  end

  def create_pet_type
    # Use find_or_create_by to avoid duplicate key errors
    species = Species.find_or_create_by!(name: "Test Species #{SecureRandom.hex(4)}")
    color = Color.find_or_create_by!(name: "Test Color #{SecureRandom.hex(4)}")
    PetType.create!(
      species_id: species.id,
      color_id: color.id,
      body_id: 0
    )
  end

  def create_pet_state
    pet_type = create_pet_type
    PetState.create!(
      pet_type: pet_type,
      swf_asset_ids: []
    )
  end

  def create_alt_style
    # Use find_or_create_by to avoid duplicate key errors
    species = Species.find_or_create_by!(name: "Test Species #{SecureRandom.hex(4)}")
    color = Color.find_or_create_by!(name: "Test Color #{SecureRandom.hex(4)}")
    AltStyle.create!(
      species_id: species.id,
      color_id: color.id,
      body_id: 0,
      series_name: "Test Series",
      thumbnail_url: "http://example.com/thumb.png"
    )
  end
end
