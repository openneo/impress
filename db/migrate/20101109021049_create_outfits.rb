class CreateOutfits < ActiveRecord::Migration[4.2]
  def self.up
    create_table :outfits do |t|
      t.integer :pet_state_id
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :outfits
  end
end
