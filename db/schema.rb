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

ActiveRecord::Schema[7.1].define(version: 2026_02_02_231043) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attachments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.string "attachable_type", null: false
    t.bigint "attachable_id", null: false
    t.string "kind"
    t.string "title"
    t.text "body"
    t.jsonb "metadata"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_attachments_on_attachable"
    t.index ["company_id"], name: "index_attachments_on_company_id"
    t.index ["created_by_id"], name: "index_attachments_on_created_by_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.string "title"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_conversations_on_company_id"
    t.index ["created_by_id"], name: "index_conversations_on_created_by_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.string "role"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_memberships_on_company_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "outputs", force: :cascade do |t|
    t.bigint "prompt_id", null: false
    t.string "kind"
    t.jsonb "content"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prompt_id"], name: "index_outputs_on_prompt_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.text "instruction"
    t.string "status"
    t.datetime "frozen_at"
    t.string "llm_provider"
    t.string "llm_model"
    t.text "prompt_snapshot"
    t.jsonb "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conversation_id", null: false
    t.string "error_message"
    t.index ["company_id"], name: "index_prompts_on_company_id"
    t.index ["conversation_id"], name: "index_prompts_on_conversation_id"
    t.index ["created_by_id"], name: "index_prompts_on_created_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "attachments", "companies"
  add_foreign_key "attachments", "users", column: "created_by_id"
  add_foreign_key "conversations", "companies"
  add_foreign_key "conversations", "users", column: "created_by_id"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "outputs", "prompts"
  add_foreign_key "prompts", "companies"
  add_foreign_key "prompts", "conversations"
  add_foreign_key "prompts", "users", column: "created_by_id"
end
