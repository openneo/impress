class AddManualSpecialColorIdToItems < ActiveRecord::Migration
  def change
    add_column :items, :manual_special_color_id, :integer
  end
end
