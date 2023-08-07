class RemoveTranslatedFieldsFromItems < ActiveRecord::Migration[3.2]
  def self.up
    remove_column :items, :name
    remove_column :items, :description
    remove_column :items, :rarity
  end

  def self.down
    add_column :items, :name, :limit => 100, :null => false
    add_column :items, :description, :limit => 16777215, :null => false
    add_columm :items, :rarity, :limit => 25
  end
end
