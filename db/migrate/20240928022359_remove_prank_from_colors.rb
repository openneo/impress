class RemovePrankFromColors < ActiveRecord::Migration[7.2]
  def change
    remove_column "colors", "prank", :boolean, default: false, null: false
  end
end
