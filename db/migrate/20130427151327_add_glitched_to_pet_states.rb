class AddGlitchedToPetStates < ActiveRecord::Migration[3.2]
  def change
    add_column :pet_states, :glitched, :boolean, null: false, default: false
  end
end
