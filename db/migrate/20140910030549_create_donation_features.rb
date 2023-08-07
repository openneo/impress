class CreateDonationFeatures < ActiveRecord::Migration[4.2]
  def change
    create_table :donation_features do |t|
      t.integer :donation_id, null: false
      t.integer :outfit_id

      t.timestamps
    end
  end
end
