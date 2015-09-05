class AddBasicImageHashToPetTypes < ActiveRecord::Migration
  def change
    add_column :pet_types, :basic_image_hash, :string
  end
end
