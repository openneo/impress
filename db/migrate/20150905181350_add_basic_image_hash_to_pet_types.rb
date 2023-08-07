class AddBasicImageHashToPetTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :pet_types, :basic_image_hash, :string
  end
end
