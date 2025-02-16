class AddFullNameToAltStyles < ActiveRecord::Migration[8.0]
  def change
    add_column :alt_styles, :full_name, :string, null: true
  end
end
