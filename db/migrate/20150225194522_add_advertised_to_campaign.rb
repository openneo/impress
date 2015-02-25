class AddAdvertisedToCampaign < ActiveRecord::Migration
  def change
    add_column :campaigns, :advertised, :boolean, null: false, default: true
  end
end
