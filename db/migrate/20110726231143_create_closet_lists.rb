class CreateClosetLists < ActiveRecord::Migration[3.2]
  def self.up
    create_table :closet_lists do |t|
      t.string :name
      t.text :description
      t.integer :user_id
      t.boolean :hangers_owned, :null => false

      t.timestamps
    end

    add_column :closet_hangers, :list_id, :integer
  end

  def self.down
    drop_table :closet_lists

    remove_column :closet_hangers, :list_id
  end
end

