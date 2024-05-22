class AddPbItemNameToColors < ActiveRecord::Migration[7.1]
  def change
    add_column :colors, :pb_item_name, :string
  end
end
