class AddCampaignIdToDonation < ActiveRecord::Migration[3.2]
  def change
    add_column :donations, :campaign_id, :integer, null: false
  end
end
