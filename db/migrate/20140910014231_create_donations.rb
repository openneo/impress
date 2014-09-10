class CreateDonations < ActiveRecord::Migration
  def change
    create_table :donations do |t|
      t.integer :amount, null: false
      t.string :charge_id, null: false
      t.integer :user_id
      t.string :donor_name
      t.string :secret

      t.timestamps
    end
  end
end
