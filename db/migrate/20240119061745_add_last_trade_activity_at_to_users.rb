class AddLastTradeActivityAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :last_trade_activity_at, :timestamp

    reversible do |direction|
      direction.up do
        User.find_in_batches do |users|
          # Find the last ClosetList/ClosetHanger updated_at timestamp for each
          # user, for trading lists/hangers only.
          max_closet_list_updated_at_by_user_id = ClosetList.
            trading.
            group(:user_id).
            where(user_id: users.map(&:id)).
            maximum(:updated_at)
          max_closet_hanger_updated_at_by_user_id = ClosetHanger.
            trading.
            group(:user_id).
            where(user_id: users.map(&:id)).
            maximum(:updated_at)

          # Set `last_trade_activity_at` to the largest such `updated_at` for
          # that user, or nil if there's none.
          User.transaction do
            users.each do |user|
              user.last_trade_activity_at = [
                max_closet_list_updated_at_by_user_id[user.id],
                max_closet_hanger_updated_at_by_user_id[user.id],
              ].filter(&:present?).max
              user.save!
            end
          end
        end
      end
    end
  end
end
