class AddUniqueIndexForOmniauthToUsers < ActiveRecord::Migration[7.1]
  def change
    add_index :users, [:provider, :uid], unique: true
  end
end
