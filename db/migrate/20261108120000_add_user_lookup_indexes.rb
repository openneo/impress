# Indexes for looking up a user's data by user, which account deletion does,
# and which `ApplicationController#current_user` does on every request.
#
# These build in place, without blocking writes (MariaDB online DDL). Each one
# still needs a brief metadata lock to start, though, so we don't wait long for
# it: if a long-running transaction is holding the table, it's better for the
# migration to fail fast (and be re-run) than for every request to queue up
# behind it. `if_not_exists` makes re-running after a partial failure safe.
class AddUserLookupIndexes < ActiveRecord::Migration[8.1]
  INDEXES = [
    # `User.where(remote_id: auth_user.id)`: used to find the current user on
    # every request, and by `AuthUser#user`.
    [:users, :remote_id],

    # Account deletion. (Scanning a whole table inside its transaction also
    # locks every row in it, until the deletion commits.)
    [:neopets_connections, :user_id],
    [:donations, :user_id],
    [:donation_features, :outfit_id],

    # Loading a donation's features, e.g. on campaign pages and in exports.
    [:donation_features, :donation_id],
  ]

  def up
    execute "SET SESSION lock_wait_timeout = 10"
    INDEXES.each do |table, column|
      add_index table, column, algorithm: :inplace, if_not_exists: true
    end
  end

  def down
    INDEXES.each do |table, column|
      remove_index table, column, if_exists: true
    end
  end
end
