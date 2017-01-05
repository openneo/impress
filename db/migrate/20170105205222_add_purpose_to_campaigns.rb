class AddPurposeToCampaigns < ActiveRecord::Migration
  def change
    # We're using the "name" column as a short campaign purpose phrase.
    # Let's name that "purpose" instead, and create a "name" column that we can
    # use to reference the campaign, e.g. "2016".
    rename_column :campaigns, :name, :purpose
    add_column :campaigns, :name, :string
  end
end
