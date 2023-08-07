class AddAdvertisedToCampaign < ActiveRecord::Migration[3.2]
  def change
    add_column :campaigns, :advertised, :boolean, null: false, default: true
  end
end
