require_relative '../../rails_helper'

# A tripwire for privacy: if you add a column that points at a user (or at
# something a user owns, like an outfit or item list), this spec fails until
# you've decided how account deletion and data export should handle it.
#
# It scans the real database schema, so it catches new tables and columns no
# matter where they're added.
RSpec.describe "User data coverage for account deletion and export" do
  # Every column that refers to a user, or to a user's outfits or item lists,
  # and what `AuthUser::Deletion` and `AuthUser::DataExport` do with it.
  let(:handled_user_data_columns) do
    {
      "closet_hangers.user_id" => "deleted; exported as `items`",
      "closet_hangers.list_id" => "deleted with the hanger; exported as `items[].list_id`",
      "closet_lists.user_id" => "deleted; exported as `item_lists`",
      "contributions.user_id" => "deleted; exported as `contributions` (the contributed data itself stays)",
      "donation_features.outfit_id" => "detached (set to NULL); exported as `donations[].featured_outfit_ids`",
      "donations.user_id" => "detached, with donor name/email cleared; exported as `donations`",
      "item_outfit_relationships.outfit_id" => "deleted with the outfit; exported as `outfits[].worn_items` and `closeted_items`",
      "login_cookies.user_id" => "deleted; not exported (legacy login credentials)",
      "neologin_cookies.created_by_id" => "detached (set to NULL); not exported (support-staff tooling, and staff can't self-delete)",
      "neopets_connections.user_id" => "deleted; exported as `neopets_connections`",
      "outfits.user_id" => "deleted; exported as `outfits`",
    }
  end

  # Columns that look like references to these tables, by name or by an actual
  # foreign key.
  let(:user_data_tables) { %w(users outfits closet_lists) }
  let(:user_data_column_pattern) { /(\A|_)(user|outfit|list)_id\z|_by_id\z/ }

  def user_data_columns
    connection = ApplicationRecord.connection
    connection.tables.flat_map do |table|
      by_name = connection.columns(table).map(&:name).
        grep(user_data_column_pattern)
      by_foreign_key = connection.foreign_keys(table).
        select { |fk| user_data_tables.include?(fk.to_table) }.map(&:column)
      (by_name + by_foreign_key).uniq.map { |column| "#{table}.#{column}" }
    end
  end

  it "knows how deletion and export handle every column that refers to user data" do
    unhandled = user_data_columns - handled_user_data_columns.keys

    expect(unhandled).to be_empty, <<~MESSAGE
      These columns look like they refer to user data, but account deletion
      and export don't know about them yet:

        #{unhandled.join("\n  ")}

      To fix this, decide what should happen to this data when someone deletes
      their account, and whether it belongs in their data export. Then:

        1. Handle it in app/models/auth_user/deletion.rb
        2. Include it in app/models/auth_user/data_export.rb (or note why not)
        3. Add a test for it in spec/models/auth_user/
        4. Add it to `handled_user_data_columns` in this file

      If it's not actually user data, add it to the list anyway, with a note
      explaining why.
    MESSAGE
  end

  it "doesn't list columns that no longer exist" do
    stale = handled_user_data_columns.keys - user_data_columns
    expect(stale).to be_empty,
      "These are listed in `handled_user_data_columns`, but aren't in the " +
      "schema anymore. Remove them (and any handling code): #{stale.join(", ")}"
  end
end
