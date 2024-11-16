class IncreaseIdLimits < ActiveRecord::Migration[7.2]
  def change
    reversible do |direction|
      direction.up do
        change_column :parents_swf_assets, :parent_id, :integer, null: false
        change_column :parents_swf_assets, :swf_asset_id, :integer, null: false
        change_column :pet_states, :pet_type_id, :integer, null: false
        change_column :pets, :pet_type_id, :integer, null: false
        change_column :swf_assets, :zone_id, :integer, null: false
      end

      direction.down do
        change_column :parents_swf_assets, :parent_id, :integer, limit: 3, null: false
        change_column :parents_swf_assets, :swf_asset_id, :integer, limit: 3, null: false
        change_column :pet_states, :pet_type_id, :integer, limit: 3, null: false
        change_column :pets, :pet_type_id, :integer, limit: 3, null: false
        change_column :swf_assets, :zone_id, :integer, limit: 1, null: false
      end
    end
  end
end
