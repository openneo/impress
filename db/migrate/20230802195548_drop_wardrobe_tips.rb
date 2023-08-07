class DropWardrobeTips < ActiveRecord::Migration[3.2]
  def change
    drop_table :wardrobe_tips do |t|
      t.integer  "index",      null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    drop_table :wardrobe_tip_translations do |t|
      t.integer  "wardrobe_tip_id"
      t.string   "locale"
      t.text     "body"
      t.datetime "created_at",      null: false
      t.datetime "updated_at",      null: false
    end
  end
end
