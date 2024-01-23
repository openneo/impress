class AddNameToSpeciesAndColor < ActiveRecord::Migration[7.1]
  def change
    add_column :species, :name, :string, null: false
    add_column :colors, :name, :string, null: false

    Species.find_each do |species|
      species.name = species.translation_for(:en).name
      species.save!
    end

    Color.find_each do |color|
      color.name = color.translation_for(:en).name
      color.save!
    end
  end
end
