class CreateObjects < ActiveRecord::Migration
  def self.up
    create_table :objects do |t|
      t.string :name
      t.string :species_support_ids

      t.timestamps
    end
  end

  def self.down
    drop_table :objects
  end
end
