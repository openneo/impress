require 'test_helper'

class TradeActivityTest < ActiveSupport::TestCase
	test "New user's last trade activity is nil" do
		user = create_user
		assert_nil user.last_trade_activity_at
	end

	test "Adding or removing items in a Trading list updates last trade activity" do
		user = create_user

		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:trading].id)
		hanger = create_closet_hanger(user: user, list: list)
		created_at = Time.now

		assert_equal created_at, user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_equal created_at + 1.day, user.last_trade_activity_at
	end

	test "Adding or removing items in a Public list does not update last trade activity" do
		user = create_user

		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:public].id)
		hanger = create_closet_hanger(user: user, list: list)

		assert_nil user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Adding or removing items in a Private list does not update last trade activity" do
		user = create_user

		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:private].id)
		hanger = create_closet_hanger(user: user, list: list)

		assert_nil user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Adding or removing items in a Trading default-list updates last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:trading].id,
			wanted_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		hanger = create_closet_hanger(user: user, owned: true)
		created_at = Time.now

		assert_equal created_at, user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_equal created_at + 1.day, user.last_trade_activity_at
	end

	test "Adding or removing items in a Public default-list does not update last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:public].id,
			wanted_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		hanger = create_closet_hanger(user: user, owned: true)

		assert_nil user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Adding or removing items in a Private default-list does not update last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:private].id,
			wanted_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		hanger = create_closet_hanger(user: user, owned: true)

		assert_nil user.last_trade_activity_at

		travel 1.day
		hanger.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Creating, editing, or deleting a Trading list updates last trade activity" do
		user = create_user
		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:trading].id
		)
		created_at = Time.now

		assert_equal created_at, user.last_trade_activity_at

		travel 1.day
		list.update!(description: "Hello, world!")

		assert_equal created_at + 1.day, user.last_trade_activity_at

		travel 1.day
		list.destroy!

		assert_equal created_at + 2.day, user.last_trade_activity_at
	end

	test "Creating, editing, or deleting a Public list does not update last trade activity" do
		user = create_user
		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:public].id
		)

		assert_nil user.last_trade_activity_at

		travel 1.day
		list.update!(description: "Hello, world!")

		assert_nil user.last_trade_activity_at

		travel 1.day
		list.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Creating, editing, or deleting a Private list does not update last trade activity" do
		user = create_user
		list = create_closet_list(
			user: user, visibility: ClosetVisibility[:private].id
		)

		assert_nil user.last_trade_activity_at

		travel 1.day
		list.update!(description: "Hello, world!")

		assert_nil user.last_trade_activity_at

		travel 1.day
		list.destroy!

		assert_nil user.last_trade_activity_at
	end

	test "Updating default-list visibility to Trading updates last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		assert_nil user.last_trade_activity_at

		user.update!(
			owned_closet_hangers_visibility: ClosetVisibility[:trading].id,
		)

		assert_equal Time.now, user.last_trade_activity_at
	end

	test "Updating default-list visibility to Public does not update last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		assert_nil user.last_trade_activity_at

		user.update!(
			owned_closet_hangers_visibility: ClosetVisibility[:public].id,
		)

		assert_nil user.last_trade_activity_at
	end

	test "Updating default-list visibility to Private does not update last trade activity" do
		user = create_user(
			owned_closet_hangers_visibility: ClosetVisibility[:public].id,
		)

		assert_nil user.last_trade_activity_at

		user.update!(
			owned_closet_hangers_visibility: ClosetVisibility[:private].id,
		)

		assert_nil user.last_trade_activity_at
	end

	setup do
		freeze_time # to compare timestamps accurately
	end

	private

	def create_user(**args)
		auth_user = AuthUser.create!(
			name: 'test', email: 'test@example.com', password: 'test123!'
		)
		auth_user.user.update!(**args) unless args.empty?
		auth_user.user
	end

	def create_closet_list(**args)
		num = ClosetList.count + 1
		ClosetList.create!(name: "Test List #{num}", hangers_owned: true, **args)
	end

	def create_closet_hanger(**args)
		ClosetHanger.create!(item: Item.first, quantity: 1, **args)
	end
end
