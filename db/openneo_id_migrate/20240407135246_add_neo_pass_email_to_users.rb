class AddNeoPassEmailToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :neopass_email, :string
  end
end
