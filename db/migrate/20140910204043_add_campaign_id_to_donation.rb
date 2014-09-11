class AddCampaignIdToDonation < ActiveRecord::Migration
  def change
    add_column :donations, :campaign_id, :integer, null: false
  end
end
