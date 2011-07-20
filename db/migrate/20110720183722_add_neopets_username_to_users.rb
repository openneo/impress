class AddNeopetsUsernameToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :neopets_username, :string
  end

  def self.down
    remove_column :users, :neopets_username
  end
end
