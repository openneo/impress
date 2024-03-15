class AllowNullEmailAndPasswordForUsers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :users, :email, true
    change_column_null :users, :encrypted_password, true
    change_column_null :users, :password_salt, true
  end
end
