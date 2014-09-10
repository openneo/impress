# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140910014231) do

  create_table "auth_servers", :force => true do |t|
    t.string "short_name", :limit => 10,       :null => false
    t.string "name",       :limit => 40,       :null => false
    t.text   "icon",       :limit => 16777215, :null => false
    t.text   "gateway",    :limit => 16777215, :null => false
    t.string "secret",     :limit => 64,       :null => false
  end

  create_table "campaign_translations", :force => true do |t|
    t.integer  "campaign_id"
    t.string   "locale"
    t.string   "progress_bar_message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "campaign_translations", ["campaign_id"], :name => "index_campaign_translations_on_campaign_id"
  add_index "campaign_translations", ["locale"], :name => "index_campaign_translations_on_locale"

  create_table "campaigns", :force => true do |t|
    t.integer  "goal_cents"
    t.integer  "progress_cents"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "campaigns_old", :force => true do |t|
    t.integer  "goal_cents",     :null => false
    t.integer  "progress_cents", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "closet_hangers", :force => true do |t|
    t.integer  "item_id"
    t.integer  "user_id"
    t.integer  "quantity"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "owned",      :default => true, :null => false
    t.integer  "list_id"
  end

  add_index "closet_hangers", ["item_id", "owned"], :name => "index_closet_hangers_on_item_id_and_owned"
  add_index "closet_hangers", ["list_id"], :name => "index_closet_hangers_on_list_id"
  add_index "closet_hangers", ["user_id"], :name => "index_closet_hangers_on_user_id"

  create_table "closet_lists", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "user_id"
    t.boolean  "hangers_owned",                :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "visibility",    :default => 1, :null => false
  end

  add_index "closet_lists", ["user_id"], :name => "index_closet_lists_on_user_id"

  create_table "color_translations", :force => true do |t|
    t.integer  "color_id"
    t.string   "locale"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "color_translations", ["color_id"], :name => "index_color_translations_on_color_id"
  add_index "color_translations", ["locale"], :name => "index_color_translations_on_locale"

  create_table "colors", :force => true do |t|
    t.boolean "basic"
    t.boolean "standard"
    t.boolean "prank",    :default => false, :null => false
  end

  create_table "contributions", :force => true do |t|
    t.string   "contributed_type", :limit => 8, :null => false
    t.integer  "contributed_id",                :null => false
    t.integer  "user_id",                       :null => false
    t.datetime "created_at",                    :null => false
  end

  add_index "contributions", ["contributed_id", "contributed_type"], :name => "index_contributions_on_contributed_id_and_contributed_type"
  add_index "contributions", ["user_id"], :name => "index_contributions_on_user_id"

  create_table "donations", :force => true do |t|
    t.integer  "amount",     :null => false
    t.string   "charge_id",  :null => false
    t.integer  "user_id"
    t.string   "donor_name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "donations_old", :force => true do |t|
    t.integer  "amount_cents", :null => false
    t.integer  "campaign_id",  :null => false
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "forums", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sort_index"
  end

  create_table "item_outfit_relationships", :force => true do |t|
    t.integer  "item_id"
    t.integer  "outfit_id"
    t.boolean  "is_worn"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "item_outfit_relationships", ["item_id"], :name => "index_item_outfit_relationships_on_item_id"
  add_index "item_outfit_relationships", ["outfit_id", "is_worn"], :name => "index_item_outfit_relationships_on_outfit_id_and_is_worn"

  create_table "item_translations", :force => true do |t|
    t.integer  "item_id"
    t.string   "locale"
    t.string   "name"
    t.text     "description"
    t.string   "rarity"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "temporary",   :default => false, :null => false
  end

  add_index "item_translations", ["item_id"], :name => "index_item_translations_on_item_id"
  add_index "item_translations", ["locale"], :name => "index_item_translations_on_locale"
  add_index "item_translations", ["name"], :name => "index_item_translations_on_name"

  create_table "items", :force => true do |t|
    t.text     "zones_restrict",                                                  :null => false
    t.text     "thumbnail_url",            :limit => 16777215,                    :null => false
    t.string   "category",                 :limit => 50
    t.string   "type",                     :limit => 50
    t.integer  "rarity_index",             :limit => 2
    t.integer  "price",                    :limit => 3,                           :null => false
    t.integer  "weight_lbs",               :limit => 2
    t.text     "species_support_ids",      :limit => 16777215
    t.boolean  "sold_in_mall",                                                    :null => false
    t.datetime "last_spidered"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "explicitly_body_specific",                     :default => false, :null => false
  end

  add_index "items", ["last_spidered"], :name => "objects_last_spidered"

  create_table "login_cookies", :force => true do |t|
    t.integer "user_id", :null => false
    t.integer "series",  :null => false
    t.integer "token",   :null => false
  end

  add_index "login_cookies", ["user_id", "series"], :name => "login_cookies_user_id_and_series"
  add_index "login_cookies", ["user_id"], :name => "login_cookies_user_id"

  create_table "neopets_connections", :force => true do |t|
    t.integer  "user_id"
    t.string   "neopets_username"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "outfit_features", :force => true do |t|
    t.integer  "donation_id"
    t.integer  "outfit_id"
    t.boolean  "approved",    :default => false, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "outfit_features_old", :force => true do |t|
    t.integer  "outfit_id",            :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "frontpage_start_date"
    t.date     "frontpage_end_date"
  end

  create_table "outfits", :force => true do |t|
    t.integer  "pet_state_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.boolean  "starred",           :default => false, :null => false
    t.string   "image"
    t.string   "image_layers_hash"
    t.boolean  "image_enqueued",    :default => false, :null => false
    t.boolean  "image_dirty",       :default => false, :null => false
  end

  add_index "outfits", ["pet_state_id"], :name => "index_outfits_on_pet_state_id"
  add_index "outfits", ["user_id"], :name => "index_outfits_on_user_id"

  create_table "parents_swf_assets", :force => true do |t|
    t.integer "parent_id",    :limit => 3, :null => false
    t.integer "swf_asset_id", :limit => 3, :null => false
    t.string  "parent_type",  :limit => 8, :null => false
  end

  add_index "parents_swf_assets", ["parent_id", "parent_type"], :name => "index_parents_swf_assets_on_parent_id_and_parent_type"
  add_index "parents_swf_assets", ["parent_id", "swf_asset_id"], :name => "unique_parents_swf_assets", :unique => true
  add_index "parents_swf_assets", ["swf_asset_id"], :name => "parents_swf_assets_swf_asset_id"

  create_table "pet_loads", :force => true do |t|
    t.string   "pet_name",   :limit => 20,       :null => false
    t.text     "amf",        :limit => 16777215, :null => false
    t.datetime "created_at",                     :null => false
  end

  create_table "pet_states", :force => true do |t|
    t.integer "pet_type_id",             :limit => 3,                    :null => false
    t.text    "swf_asset_ids",                                           :null => false
    t.boolean "female"
    t.integer "mood_id"
    t.boolean "unconverted"
    t.boolean "labeled",                              :default => false, :null => false
    t.boolean "glitched",                             :default => false, :null => false
    t.string  "artist_neopets_username"
  end

  add_index "pet_states", ["pet_type_id"], :name => "pet_states_pet_type_id"

  create_table "pet_types", :force => true do |t|
    t.integer  "color_id",   :limit => 1, :null => false
    t.integer  "species_id", :limit => 1, :null => false
    t.datetime "created_at",              :null => false
    t.integer  "body_id",    :limit => 2, :null => false
    t.string   "image_hash", :limit => 8
  end

  add_index "pet_types", ["species_id", "color_id"], :name => "pet_types_species_color", :unique => true

  create_table "pets", :force => true do |t|
    t.string  "name",        :limit => 20, :null => false
    t.integer "pet_type_id", :limit => 3,  :null => false
  end

  add_index "pets", ["name"], :name => "pets_name", :unique => true
  add_index "pets", ["pet_type_id"], :name => "pets_pet_type_id"

  create_table "posts", :force => true do |t|
    t.integer  "topic_id"
    t.integer  "user_id"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "species", :force => true do |t|
  end

  create_table "species_translations", :force => true do |t|
    t.integer  "species_id"
    t.string   "locale"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "species_translations", ["locale"], :name => "index_species_translations_on_locale"
  add_index "species_translations", ["species_id"], :name => "index_species_translations_on_species_id"

  create_table "swf_assets", :force => true do |t|
    t.string   "type",               :limit => 7,                           :null => false
    t.integer  "remote_id",          :limit => 3,                           :null => false
    t.text     "url",                :limit => 16777215,                    :null => false
    t.integer  "zone_id",            :limit => 1,                           :null => false
    t.text     "zones_restrict",                                            :null => false
    t.datetime "created_at",                                                :null => false
    t.integer  "body_id",            :limit => 2,                           :null => false
    t.boolean  "has_image",                              :default => false, :null => false
    t.boolean  "image_requested",                        :default => false, :null => false
    t.datetime "reported_broken_at"
    t.datetime "converted_at"
    t.boolean  "image_manual",                           :default => false, :null => false
  end

  add_index "swf_assets", ["body_id"], :name => "swf_assets_body_id_and_object_id"
  add_index "swf_assets", ["type", "remote_id"], :name => "swf_assets_type_and_id"
  add_index "swf_assets", ["zone_id"], :name => "idx_swf_assets_zone_id"

  create_table "topics", :force => true do |t|
    t.string   "title"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "forum_id"
    t.integer  "original_post_id"
  end

  create_table "users", :force => true do |t|
    t.string   "name",                             :limit => 20,                    :null => false
    t.integer  "auth_server_id",                   :limit => 1,                     :null => false
    t.integer  "remote_id",                                                         :null => false
    t.integer  "points",                                         :default => 0,     :null => false
    t.boolean  "beta",                                           :default => false, :null => false
    t.string   "remember_token"
    t.datetime "remember_created_at"
    t.boolean  "forum_admin",                                    :default => false, :null => false
    t.boolean  "forum_moderator"
    t.boolean  "image_mode_tester",                              :default => false, :null => false
    t.text     "closet_description",                                                :null => false
    t.integer  "owned_closet_hangers_visibility",                :default => 1,     :null => false
    t.integer  "wanted_closet_hangers_visibility",               :default => 1,     :null => false
    t.integer  "contact_neopets_connection_id"
  end

  create_table "wardrobe_tip_translations", :force => true do |t|
    t.integer  "wardrobe_tip_id"
    t.string   "locale"
    t.text     "body"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "wardrobe_tip_translations", ["locale"], :name => "index_wardrobe_tip_translations_on_locale"
  add_index "wardrobe_tip_translations", ["wardrobe_tip_id"], :name => "index_wardrobe_tip_translations_on_wardrobe_tip_id"

  create_table "wardrobe_tips", :force => true do |t|
    t.integer  "index",      :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "zone_translations", :force => true do |t|
    t.integer  "zone_id"
    t.string   "locale"
    t.string   "label"
    t.string   "plain_label"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "zone_translations", ["locale"], :name => "index_zone_translations_on_locale"
  add_index "zone_translations", ["zone_id"], :name => "index_zone_translations_on_zone_id"

  create_table "zones", :force => true do |t|
    t.integer "depth"
    t.integer "type_id"
  end

end
