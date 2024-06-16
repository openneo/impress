class AddThumbnailUrlToAltStyles < ActiveRecord::Migration[7.1]
  def change
    add_column :alt_styles, :thumbnail_url, :string, null: false

    reversible do |direction|
      direction.up do
        AltStyle.find_each do |alt_style|
          alt_style.infer_thumbnail_url
          alt_style.save!
        end
      end
    end
  end
end
