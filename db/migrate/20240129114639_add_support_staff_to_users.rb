class AddSupportStaffToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :support_staff, :boolean, null: false, default: false
  end
end
