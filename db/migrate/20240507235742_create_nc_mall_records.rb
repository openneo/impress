class CreateNCMallRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :nc_mall_records do |t|
      t.references :item, type: :integer, null: false, foreign_key: true
      t.integer :price, null: false
      t.integer :discount_price
      t.datetime :discount_begins_at
      t.datetime :discount_ends_at

      t.timestamps
    end
  end
end
