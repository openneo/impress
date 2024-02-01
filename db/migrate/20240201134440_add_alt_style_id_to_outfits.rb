class AddAltStyleIdToOutfits < ActiveRecord::Migration[7.1]
  def change
    add_reference :outfits, :alt_style, null: true, foreign_key: true
  end
end
