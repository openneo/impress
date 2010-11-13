class AddBetaToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :beta, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :beta
  end
end
