class AddThemeIdToCampaigns < ActiveRecord::Migration
  def change
    add_column :campaigns, :theme_id, :string, null: false, default: 'hug'
  end
end
