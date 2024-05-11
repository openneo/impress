class AddUniqueIndexOnItemIdToNCMallRecords < ActiveRecord::Migration[7.1]
  def change
    # NOTE: We need to temporarily remove the foreign key, then add it back
    # once the index is in.
    remove_foreign_key :nc_mall_records, :items
    remove_index :nc_mall_records, :item_id

    add_index :nc_mall_records, :item_id, unique: true
    add_foreign_key :nc_mall_records, :items
  end
end
