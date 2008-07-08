# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 15) do

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

  create_table "ent_questions", :force => true do |t|
    t.string  "question_name"
    t.integer "max_point"
  end

  create_table "ent_seqs", :force => true do |t|
    t.text   "seq_src"
    t.string "seq_title"
  end

  create_table "ent_tests", :force => true do |t|
    t.string  "test_name"
    t.integer "max_sum_point"
  end

  create_table "level_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.integer  "level"
    t.datetime "created_on"
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

  create_table "question_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.integer  "ent_module_id"
    t.integer  "ent_test_id"
    t.integer  "ent_question_id"
    t.integer  "point"
    t.datetime "created_on"
  end

  create_table "rule_search_time_logs", :force => true do |t|
    t.integer "user_id"
    t.string  "time_name"
    t.time    "time_value"
  end

  create_table "seq_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.datetime "created_on"
  end

  create_table "test_logs", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ent_seq_id"
    t.integer  "ent_module_id"
    t.integer  "ent_test_id"
    t.integer  "sum_point"
    t.datetime "created_on"
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
