class AddPrankToColors < ActiveRecord::Migration[3.2]
  def change
    add_column :colors, :prank, :boolean, default: false, null: false
  end
end
