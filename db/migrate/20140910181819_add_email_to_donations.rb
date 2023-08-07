class AddEmailToDonations < ActiveRecord::Migration[4.2]
  def change
    add_column :donations, :donor_email, :string
  end
end
