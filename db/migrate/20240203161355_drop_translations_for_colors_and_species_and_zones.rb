class DropTranslationsForColorsAndSpeciesAndZones < ActiveRecord::Migration[7.1]
  def change
    drop_table "color_translations", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
      t.integer "color_id"
      t.string "locale"
      t.string "name"
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.index ["color_id"], name: "index_color_translations_on_color_id"
      t.index ["locale"], name: "index_color_translations_on_locale"
    end

    drop_table "species_translations", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
      t.integer "species_id"
      t.string "locale"
      t.string "name"
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.index ["locale"], name: "index_species_translations_on_locale"
      t.index ["species_id"], name: "index_species_translations_on_species_id"
    end

    drop_table "zone_translations", id: :integer, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
      t.integer "zone_id"
      t.string "locale"
      t.string "label"
      t.string "plain_label"
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.index ["locale"], name: "index_zone_translations_on_locale"
      t.index ["zone_id"], name: "index_zone_translations_on_zone_id"
    end
  end
end
