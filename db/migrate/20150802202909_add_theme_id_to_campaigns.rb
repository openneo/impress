class AddThemeIdToCampaigns < ActiveRecord::Migration[3.2]
  def change
    add_column :campaigns, :theme_id, :string, null: false, default: 'hug'
  end
end
