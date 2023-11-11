class RemoveImageModeTesterFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :image_mode_tester, :boolean, default: false, null: false
  end
end
