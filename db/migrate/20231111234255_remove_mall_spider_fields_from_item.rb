class RemoveMallSpiderFieldsFromItem < ActiveRecord::Migration[7.1]
  def change
    remove_column :items, :sold_in_mall, default: false, null: false
    remove_column :items, :last_spidered, precision: nil
  end
end
