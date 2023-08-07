class CreateSpecies < ActiveRecord::Migration[3.2]
  def self.up
    create_table :species
    Species.create_translation_table! :name => :string
  end

  def self.down
    drop_table :species
    Species.drop_translation_table!
  end
end
