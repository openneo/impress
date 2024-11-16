class IncreasePetTypeColorIdAndSpeciesIdLimit < ActiveRecord::Migration[7.2]
  def change
    reversible do |direction|
      change_table :pet_types do |t|
        direction.up do
          t.change :color_id, :integer, null: false
          t.change :species_id, :integer, null: false
        end

        direction.down do
          t.change :color_id, :integer, limit: 1, null: false
          t.change :species_id, :integer, limit: 1, null: false
        end
      end
    end
  end
end
