class AddShadowbannedToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :shadowbanned, :boolean, default: false, null: false
  end
end
