class AddThanksToCampaign < ActiveRecord::Migration[3.2]
  def change
    add_column :campaigns, :thanks, :text
  end
end
