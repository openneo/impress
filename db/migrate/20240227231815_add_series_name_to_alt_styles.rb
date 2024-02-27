class AddSeriesNameToAltStyles < ActiveRecord::Migration[7.1]
  def change
    add_column :alt_styles, :series_name, :string, null: false,
      default: "<New?>"

    reversible do |direction|
      direction.up do
        # These IDs are determined by Neopets.com, so referencing them like
        # this should be relatively stable! Backfill the series name
        # "Nostalgic" for all alt styles in the Nostalgic ID range. (At time
        # of writing, *all* alt styles are Nostalgic, but I'm writing it like
        # this for clarity and future-proofing!)
        AltStyle.where("id >= 87249 AND id <= 87503").update_all(
          series_name: "Nostalgic")
      end
    end
  end
end
