class AddThanksToCampaign < ActiveRecord::Migration[4.2]
  def change
    add_column :campaigns, :thanks, :text
  end
end
