class CreateClosetHangers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :closet_hangers do |t|
      t.integer :item_id
      t.integer :user_id
      t.integer :quantity

      t.timestamps
    end
  end

  def self.down
    drop_table :closet_hangers
  end
end
