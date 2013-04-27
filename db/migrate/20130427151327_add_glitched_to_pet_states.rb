class AddGlitchedToPetStates < ActiveRecord::Migration
  def change
    add_column :pet_states, :glitched, :boolean, null: false, default: false
  end
end
