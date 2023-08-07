class AddThemeIdToCampaigns < ActiveRecord::Migration[4.2]
  def change
    add_column :campaigns, :theme_id, :string, null: false, default: 'hug'
  end
end
