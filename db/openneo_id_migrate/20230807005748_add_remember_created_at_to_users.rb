class AddRememberCreatedAtToUsers < ActiveRecord::Migration[7.0]
  def change
    change_table :users do |t|
      t.datetime :remember_created_at
    end
  end
end
