class AddManualSpecialColorIdToItems < ActiveRecord::Migration[3.2]
  def change
    add_column :items, :manual_special_color_id, :integer
  end
end
