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

ActiveRecord::Schema.define(:version => 20101125160843) do

  create_table "auth_servers", :force => true do |t|
    t.string "short_name", :limit => 10, :null => false
    t.string "name",       :limit => 40, :null => false
    t.text   "icon",                     :null => false
    t.text   "gateway",                  :null => false
    t.string "secret",     :limit => 64, :null => false
  end

  create_table "contributions", :force => true do |t|
    t.string   "contributed_type", :limit => 8, :null => false
    t.integer  "contributed_id",                :null => false
    t.integer  "user_id",                       :null => false
    t.datetime "created_at",                    :null => false
  end

  create_table "item_outfit_relationships", :force => true do |t|
    t.integer  "item_id"
    t.integer  "outfit_id"
    t.boolean  "is_worn"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "login_cookies", :force => true do |t|
    t.integer "user_id", :null => false
    t.integer "series",  :null => false
    t.integer "token",   :null => false
  end

  add_index "login_cookies", ["user_id", "series"], :name => "login_cookies_user_id_and_series"
  add_index "login_cookies", ["user_id"], :name => "login_cookies_user_id"

  create_table "objects", :force => true do |t|
    t.text     "zones_restrict",      :limit => 255, :null => false
    t.text     "thumbnail_url",                      :null => false
    t.string   "name",                :limit => 100, :null => false
    t.text     "description",                        :null => false
    t.string   "category",            :limit => 50
    t.string   "type",                :limit => 50
    t.string   "rarity",              :limit => 25
    t.integer  "rarity_index",        :limit => 2
    t.integer  "price",               :limit => 3,   :null => false
    t.integer  "weight_lbs",          :limit => 2
    t.text     "species_support_ids"
    t.boolean  "sold_in_mall",                       :null => false
    t.datetime "last_spidered"
  end

  add_index "objects", ["last_spidered"], :name => "objects_last_spidered"
  add_index "objects", ["name"], :name => "name"

  create_table "outfits", :force => true do |t|
    t.integer  "pet_state_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name",                            :null => false
    t.boolean  "starred",      :default => false, :null => false
  end

  create_table "parents_swf_assets", :id => false, :force => true do |t|
    t.integer "parent_id",      :limit => 3, :null => false
    t.integer "swf_asset_id",   :limit => 3, :null => false
    t.string  "swf_asset_type", :limit => 7, :null => false
  end

  add_index "parents_swf_assets", ["parent_id", "swf_asset_id", "swf_asset_type"], :name => "unique_parents_swf_assets", :unique => true
  add_index "parents_swf_assets", ["parent_id"], :name => "parent_swf_assets_parent_id"
  add_index "parents_swf_assets", ["swf_asset_id"], :name => "parents_swf_assets_swf_asset_id"

  create_table "pet_loads", :force => true do |t|
    t.string   "pet_name",   :limit => 20, :null => false
    t.text     "amf",                      :null => false
    t.datetime "created_at",               :null => false
  end

  create_table "pet_states", :force => true do |t|
    t.integer "pet_type_id",   :limit => 3,   :null => false
    t.text    "swf_asset_ids", :limit => 255, :null => false
  end

  add_index "pet_states", ["pet_type_id"], :name => "pet_states_pet_type_id"

  create_table "pet_types", :force => true do |t|
    t.integer  "color_id",   :limit => 1, :null => false
    t.integer  "species_id", :limit => 1, :null => false
    t.datetime "created_at",              :null => false
    t.integer  "body_id",    :limit => 2, :null => false
    t.string   "image_hash", :limit => 8
  end

  add_index "pet_types", ["body_id"], :name => "pet_type_body_id"
  add_index "pet_types", ["species_id", "color_id"], :name => "pet_types_species_color", :unique => true

  create_table "pets", :force => true do |t|
    t.string  "name",        :limit => 20, :null => false
    t.integer "pet_type_id", :limit => 3,  :null => false
  end

  add_index "pets", ["name"], :name => "pets_name", :unique => true
  add_index "pets", ["pet_type_id"], :name => "pets_pet_type_id"

  create_table "schema_info", :id => false, :force => true do |t|
    t.integer "version", :default => 0, :null => false
  end

  create_table "swf_assets", :id => false, :force => true do |t|
    t.string   "type",           :limit => 7,   :null => false
    t.integer  "id",             :limit => 3,   :null => false
    t.text     "url",                           :null => false
    t.integer  "zone_id",        :limit => 1,   :null => false
    t.text     "zones_restrict", :limit => 255, :null => false
    t.datetime "created_at",                    :null => false
    t.integer  "body_id",        :limit => 2,   :null => false
  end

  add_index "swf_assets", ["body_id"], :name => "swf_assets_body_id_and_object_id"
  add_index "swf_assets", ["type", "id"], :name => "swf_assets_type_and_id"
  add_index "swf_assets", ["zone_id"], :name => "idx_swf_assets_zone_id"

  create_table "users", :force => true do |t|
    t.string  "name",           :limit => 20,                    :null => false
    t.integer "auth_server_id", :limit => 1,                     :null => false
    t.integer "remote_id",                                       :null => false
    t.integer "points",                       :default => 0,     :null => false
    t.boolean "beta",                         :default => false, :null => false
  end

  create_table "zones", :force => true do |t|
    t.integer "depth",   :limit => 1,  :null => false
    t.integer "type_id", :limit => 1,  :null => false
    t.string  "type",    :limit => 40, :null => false
    t.string  "label",   :limit => 40, :null => false
  end

end
