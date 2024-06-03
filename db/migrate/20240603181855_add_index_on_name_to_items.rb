class AddIndexOnNameToItems < ActiveRecord::Migration[7.1]
  def change
    add_index :items, :name
  end
end
