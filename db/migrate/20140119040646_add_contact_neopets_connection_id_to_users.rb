class AddContactNeopetsConnectionIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :contact_neopets_connection_id, :integer

    # As it happens, this migration ran immediately after the previous one, so
    # each user with a Neopets connection only had one: their contact.
    NeopetsConnection.includes(:user).find_each do |connection|
      connection.user.contact_neopets_connection = connection
      connection.user.save!
    end
  end
end
