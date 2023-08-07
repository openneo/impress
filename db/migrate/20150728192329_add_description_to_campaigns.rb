class AddDescriptionToCampaigns < ActiveRecord::Migration[4.2]
  def change
    add_column :campaigns, :description, :text, null: false, default: ''
  end
end
