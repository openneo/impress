class AddArtistNeopetsUsernameToPetState < ActiveRecord::Migration
  def change
    add_column :pet_states, :artist_neopets_username, :string, null: true
  end
end
