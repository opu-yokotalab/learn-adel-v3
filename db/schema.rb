# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 2) do

  create_table "action_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.string   "action_code"
    t.string   "action_value"
    t.datetime "created_on"
    t.integer  "dis_code"
  end

  create_table "ent_modules", :force => true do |t|
    t.string "module_name"
    t.text   "module_src"
  end

  add_index "ent_modules", ["module_name"], :name => "ent_modules_module_name_key", :unique => true

  create_table "ent_seqs", :force => true do |t|
    t.text   "seq_src"
    t.string "seq_title"
  end

  create_table "learns", :force => true do |t|
    t.string   "name"
    t.string   "contents"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "module_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.integer  "ent_module_id"
    t.datetime "created_on"
  end

  create_table "operation_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.string   "operation_code"
    t.string   "event_arg"
    t.datetime "created_on"
    t.integer  "dis_code"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "email"
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token"
    t.datetime "remember_token_expires_at"
  end

end
