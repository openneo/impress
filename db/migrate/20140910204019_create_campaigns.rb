class CreateCampaigns < ActiveRecord::Migration
  def change
    create_table :campaigns do |t|
      t.integer :progress, null: false, default: 0
      t.integer :goal, null: false
      t.boolean :active, null: false

      t.timestamps
    end
  end
end
