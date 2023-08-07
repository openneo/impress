class AddCampaignIdToDonation < ActiveRecord::Migration[4.2]
  def change
    add_column :donations, :campaign_id, :integer, null: false
  end
end
