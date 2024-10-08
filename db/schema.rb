# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2024_10_08_004715) do
  create_table "alt_styles", charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "species_id", null: false
    t.integer "color_id", null: false
    t.integer "body_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "series_name"
    t.string "thumbnail_url", null: false
    t.index ["color_id"], name: "index_alt_styles_on_color_id"
    t.index ["species_id"], name: "index_alt_styles_on_species_id"
  end

  create_table "auth_servers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "short_name", limit: 10, null: false
    t.string "name", limit: 40, null: false
    t.text "icon", size: :long, null: false
    t.text "gateway", size: :long, null: false
    t.string "secret", limit: 64, null: false
  end

  create_table "campaigns", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "progress", default: 0, null: false
    t.integer "goal", null: false
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "advertised", default: true, null: false
    t.text "description", size: :long, null: false
    t.string "purpose", default: "our hosting costs this year", null: false
    t.string "theme_id", default: "hug", null: false
    t.text "thanks", size: :long
    t.string "name"
  end

  create_table "closet_hangers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "item_id"
    t.integer "user_id"
    t.integer "quantity"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "owned", default: true, null: false
    t.integer "list_id"
    t.index ["item_id", "owned"], name: "index_closet_hangers_on_item_id_and_owned"
    t.index ["list_id"], name: "index_closet_hangers_on_list_id"
    t.index ["user_id", "list_id", "item_id", "owned", "created_at"], name: "index_closet_hangers_test_20131226"
    t.index ["user_id", "owned", "item_id"], name: "index_closet_hangers_on_user_id_and_owned_and_item_id"
    t.index ["user_id", "owned", "list_id", "updated_at"], name: "index_closet_hangers_for_last_trade_activity"
    t.index ["user_id"], name: "index_closet_hangers_on_user_id"
  end

  create_table "closet_lists", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "name"
    t.text "description", size: :long
    t.integer "user_id"
    t.boolean "hangers_owned", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "visibility", default: 1, null: false
    t.index ["user_id"], name: "index_closet_lists_on_user_id"
  end

  create_table "colors", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.boolean "basic"
    t.boolean "standard"
    t.string "name", null: false
    t.string "pb_item_name"
    t.string "pb_item_thumbnail_url"
  end

  create_table "contributions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "contributed_type", limit: 8, null: false
    t.integer "contributed_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["contributed_id", "contributed_type"], name: "index_contributions_on_contributed_id_and_contributed_type"
    t.index ["user_id"], name: "index_contributions_on_user_id"
  end

  create_table "donation_features", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "donation_id", null: false
    t.integer "outfit_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "donations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "amount", null: false
    t.string "charge_id", null: false
    t.integer "user_id"
    t.string "donor_name"
    t.string "secret"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "donor_email"
    t.integer "campaign_id", null: false
  end

  create_table "item_outfit_relationships", charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "item_id"
    t.integer "outfit_id"
    t.boolean "is_worn"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["item_id"], name: "index_item_outfit_relationships_on_item_id"
    t.index ["outfit_id", "is_worn"], name: "index_item_outfit_relationships_on_outfit_id_and_is_worn"
  end

  create_table "items", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.text "zones_restrict", size: :medium, null: false
    t.text "thumbnail_url", size: :long, null: false
    t.string "category", limit: 50
    t.string "type", limit: 50
    t.integer "rarity_index", limit: 2
    t.integer "price", limit: 3, null: false
    t.integer "weight_lbs", limit: 2
    t.text "species_support_ids", size: :long
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "explicitly_body_specific", default: false, null: false
    t.integer "manual_special_color_id"
    t.column "modeling_status_hint", "enum('done','glitchy')"
    t.boolean "is_manually_nc", default: false, null: false
    t.string "name", null: false
    t.text "description", size: :medium, null: false
    t.string "rarity", default: "", null: false
    t.integer "dyeworks_base_item_id"
    t.string "cached_occupied_zone_ids", default: ""
    t.text "cached_compatible_body_ids", default: ""
    t.index ["dyeworks_base_item_id"], name: "index_items_on_dyeworks_base_item_id"
    t.index ["modeling_status_hint", "created_at", "id"], name: "items_modeling_status_hint_and_created_at_and_id"
    t.index ["modeling_status_hint", "created_at"], name: "items_modeling_status_hint_and_created_at"
    t.index ["modeling_status_hint", "id"], name: "items_modeling_status_hint_and_id"
    t.index ["modeling_status_hint"], name: "items_modeling_status_hint"
    t.index ["name"], name: "index_items_on_name"
  end

  create_table "login_cookies", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "series", null: false
    t.integer "token", null: false
    t.index ["user_id", "series"], name: "login_cookies_user_id_and_series"
    t.index ["user_id"], name: "login_cookies_user_id"
  end

  create_table "modeling_logs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "current_timestamp()" }, null: false
    t.text "log_json", size: :long, null: false
    t.string "pet_name", limit: 128, null: false
  end

  create_table "nc_mall_records", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "price", null: false
    t.integer "discount_price"
    t.datetime "discount_begins_at"
    t.datetime "discount_ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_nc_mall_records_on_item_id", unique: true
  end

  create_table "neopets_connections", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "user_id"
    t.string "neopets_username"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "outfits", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "pet_state_id"
    t.integer "user_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name"
    t.boolean "starred", default: false, null: false
    t.string "image"
    t.string "image_layers_hash"
    t.boolean "image_enqueued", default: false, null: false
    t.bigint "alt_style_id"
    t.index ["alt_style_id"], name: "index_outfits_on_alt_style_id"
    t.index ["pet_state_id"], name: "index_outfits_on_pet_state_id"
    t.index ["user_id"], name: "index_outfits_on_user_id"
  end

  create_table "parents_swf_assets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "parent_id", limit: 3, null: false
    t.integer "swf_asset_id", limit: 3, null: false
    t.string "parent_type", limit: 8, null: false
    t.index ["parent_id", "parent_type"], name: "index_parents_swf_assets_on_parent_id_and_parent_type"
    t.index ["parent_id", "swf_asset_id"], name: "unique_parents_swf_assets", unique: true
    t.index ["swf_asset_id"], name: "parents_swf_assets_swf_asset_id"
  end

  create_table "pet_loads", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "pet_name", limit: 20, null: false
    t.text "amf", size: :long, null: false
    t.datetime "created_at", precision: nil, null: false
  end

  create_table "pet_states", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "pet_type_id", limit: 3, null: false
    t.text "swf_asset_ids", size: :medium, null: false
    t.boolean "female"
    t.integer "mood_id"
    t.boolean "unconverted"
    t.boolean "labeled", default: false, null: false
    t.boolean "glitched", default: false, null: false
    t.string "artist_neopets_username"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["pet_type_id"], name: "pet_states_pet_type_id"
  end

  create_table "pet_types", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "color_id", limit: 1, null: false
    t.integer "species_id", limit: 1, null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "body_id", limit: 2, null: false
    t.string "image_hash", limit: 8
    t.string "basic_image_hash"
    t.index ["body_id", "color_id", "species_id"], name: "pet_types_body_id_and_color_id_and_species_id"
    t.index ["body_id"], name: "pet_types_body_id"
    t.index ["color_id", "species_id"], name: "pet_types_color_id_and_species_id"
    t.index ["color_id"], name: "pet_types_color_id"
    t.index ["species_id", "color_id"], name: "pet_types_species_color", unique: true
  end

  create_table "pets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "name", limit: 20, null: false
    t.integer "pet_type_id", limit: 3, null: false
    t.index ["name"], name: "pets_name", unique: true
    t.index ["pet_type_id"], name: "pets_pet_type_id"
  end

  create_table "species", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "swf_assets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "type", limit: 7, null: false
    t.integer "remote_id", limit: 3, null: false
    t.text "url", size: :long, null: false
    t.integer "zone_id", limit: 1, null: false
    t.text "zones_restrict", size: :medium, null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "body_id", limit: 2, null: false
    t.boolean "has_image", default: false, null: false
    t.boolean "image_requested", default: false, null: false
    t.datetime "reported_broken_at", precision: nil
    t.datetime "converted_at", precision: nil
    t.boolean "image_manual", default: false, null: false
    t.text "manifest", size: :long
    t.timestamp "manifest_cached_at"
    t.string "known_glitches", limit: 128, default: ""
    t.string "manifest_url"
    t.datetime "manifest_loaded_at"
    t.integer "manifest_status_code"
    t.index ["body_id"], name: "swf_assets_body_id_and_object_id"
    t.index ["type", "remote_id"], name: "swf_assets_type_and_id"
    t.index ["zone_id"], name: "idx_swf_assets_zone_id"
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "name", limit: 30, null: false
    t.integer "auth_server_id", limit: 1, null: false
    t.integer "remote_id", null: false
    t.integer "points", default: 0, null: false
    t.boolean "beta", default: false, null: false
    t.string "remember_token"
    t.datetime "remember_created_at", precision: nil
    t.integer "owned_closet_hangers_visibility", default: 1, null: false
    t.integer "wanted_closet_hangers_visibility", default: 1, null: false
    t.integer "contact_neopets_connection_id"
    t.timestamp "last_trade_activity_at"
    t.boolean "support_staff", default: false, null: false
    t.boolean "shadowbanned", default: false, null: false
  end

  create_table "zones", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.integer "depth"
    t.integer "type_id"
    t.string "label", null: false
    t.string "plain_label", null: false
  end

  add_foreign_key "alt_styles", "colors"
  add_foreign_key "alt_styles", "species"
  add_foreign_key "items", "items", column: "dyeworks_base_item_id"
  add_foreign_key "nc_mall_records", "items"
  add_foreign_key "outfits", "alt_styles"
end
