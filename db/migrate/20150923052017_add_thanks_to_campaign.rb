class AddThanksToCampaign < ActiveRecord::Migration
  def change
    add_column :campaigns, :thanks, :text
  end
end
