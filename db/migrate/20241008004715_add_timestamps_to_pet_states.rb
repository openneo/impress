class AddTimestampsToPetStates < ActiveRecord::Migration[7.2]
  def change
    add_timestamps :pet_states, null: true
  end
end
