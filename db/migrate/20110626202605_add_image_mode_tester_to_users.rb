class AddImageModeTesterToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :image_mode_tester, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :image_mode_tester
  end
end

