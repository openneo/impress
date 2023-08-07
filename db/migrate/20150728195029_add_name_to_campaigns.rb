class AddNameToCampaigns < ActiveRecord::Migration[4.2]
  def change
    # TODO: translations?
    add_column :campaigns, :name, :string, null: false, default: 'our hosting costs this year'
  end
end
