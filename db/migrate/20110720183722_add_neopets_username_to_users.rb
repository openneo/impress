class AddNeopetsUsernameToUsers < ActiveRecord::Migration[3.2]
  def self.up
    add_column :users, :neopets_username, :string
  end

  def self.down
    remove_column :users, :neopets_username
  end
end
