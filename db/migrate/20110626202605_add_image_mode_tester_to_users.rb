class AddImageModeTesterToUsers < ActiveRecord::Migration[3.2]
  def self.up
    add_column :users, :image_mode_tester, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :image_mode_tester
  end
end

