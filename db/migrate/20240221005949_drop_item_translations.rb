class DropItemTranslations < ActiveRecord::Migration[7.1]
  def change
    drop_table "item_translations", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
      t.integer "item_id"
      t.string "locale"
      t.string "name"
      t.text "description"
      t.string "rarity"
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.index ["item_id", "locale"], name: "index_item_translations_on_item_id_and_locale"
      t.index ["item_id"], name: "index_item_translations_on_item_id"
      t.index ["locale"], name: "index_item_translations_on_locale"
      t.index ["name"], name: "index_item_translations_name"
    end
  end
end
