class AddFemaleAndMoodAndUnconvertedAndLabeledToPetStates < ActiveRecord::Migration[3.2]
  def self.up
    add_column :pet_states, :female, :boolean
    add_column :pet_states, :mood_id, :integer
    add_column :pet_states, :unconverted, :boolean
    add_column :pet_states, :labeled, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :pet_states, :labeled
    remove_column :pet_states, :unconverted
    remove_column :pet_states, :mood_id
    remove_column :pet_states, :female
  end
end
