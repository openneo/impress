class AddNameToCampaigns < ActiveRecord::Migration
  def change
    # TODO: translations?
    add_column :campaigns, :name, :string, null: false, default: 'our hosting costs this year'
  end
end
