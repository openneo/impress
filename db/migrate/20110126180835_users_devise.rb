class UsersDevise < ActiveRecord::Migration[4.2]
  def self.up
    change_table :users do |t|
      t.rememberable
    end
  end

  def self.down
    change_table :users do |t|
      t.remove :remember_token
      t.remove :remember_created_at
    end
  end
end
