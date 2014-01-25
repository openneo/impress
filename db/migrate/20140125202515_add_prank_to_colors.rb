class AddPrankToColors < ActiveRecord::Migration
  def change
    add_column :colors, :prank, :boolean, default: false, null: false
  end
end
