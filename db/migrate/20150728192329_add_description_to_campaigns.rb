class AddDescriptionToCampaigns < ActiveRecord::Migration[3.2]
  def change
    add_column :campaigns, :description, :text, null: false, default: ''
  end
end
