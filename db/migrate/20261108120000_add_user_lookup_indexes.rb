# Indexes for looking up a user's data by user, which account deletion does,
# and which `ApplicationController#current_user` does on every request.
class AddUserLookupIndexes < ActiveRecord::Migration[8.1]
  def change
    # `User.where(remote_id: auth_user.id)`: used to find the current user on
    # every request, and by `AuthUser#user`.
    add_index :users, :remote_id

    # `NeopetsConnection.where(user_id: ...)`: user pages, and account
    # deletion, where scanning the whole table also locks every row in it.
    add_index :neopets_connections, :user_id
  end
end
