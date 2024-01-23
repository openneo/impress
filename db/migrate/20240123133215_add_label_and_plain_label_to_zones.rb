class AddLabelAndPlainLabelToZones < ActiveRecord::Migration[7.1]
  def change
    add_column :zones, :label, :string, null: false
    add_column :zones, :plain_label, :string, null: false

    reversible do |direction|
      direction.up do
        Zone.includes(:translations).find_each do |zone|
          zone.label = zone.translation_for(:en).label
          zone.plain_label = zone.translation_for(:en).plain_label
          zone.save!
        end
      end
    end
  end
end
