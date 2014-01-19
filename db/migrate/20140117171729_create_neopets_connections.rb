class CreateNeopetsConnections < ActiveRecord::Migration
  def change
    create_table :neopets_connections do |t|
      t.integer :user_id
      t.string :neopets_username

      t.timestamps
    end

    User.where('neopets_username IS NOT NULL').find_each do |user|
      connection = user.neopets_connections.build
      connection.neopets_username = user.neopets_username
      connection.save!
    end
    remove_column :users, :neopets_username
  end
end
