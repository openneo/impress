class AddArtistNeopetsUsernameToPetState < ActiveRecord::Migration[4.2]
  def change
    add_column :pet_states, :artist_neopets_username, :string, null: true
  end
end
