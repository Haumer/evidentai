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

ActiveRecord::Schema[7.1].define(version: 2026_02_06_102219) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_messages", force: :cascade do |t|
    t.bigint "user_message_id", null: false
    t.string "kind"
    t.jsonb "content"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_message_id"], name: "index_ai_messages_on_user_message_id"
  end

  create_table "artifacts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "chat_id", null: false
    t.string "kind"
    t.text "content"
    t.string "status"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id", "created_at"], name: "index_artifacts_on_chat_id_and_created_at"
    t.index ["chat_id"], name: "index_artifacts_on_chat_id"
    t.index ["company_id"], name: "index_artifacts_on_company_id"
    t.index ["created_by_id"], name: "index_artifacts_on_created_by_id"
  end

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

  create_table "chats", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.string "title"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_chats_on_company_id"
    t.index ["created_by_id"], name: "index_chats_on_created_by_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "proposed_actions", force: :cascade do |t|
    t.bigint "ai_message_id", null: false
    t.string "action_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "proposed", null: false
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "dismissed_at"
    t.bigint "dismissed_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_proposed_actions_on_action_type"
    t.index ["ai_message_id", "status"], name: "index_proposed_actions_on_ai_message_id_and_status"
    t.index ["ai_message_id"], name: "index_proposed_actions_on_ai_message_id"
    t.index ["approved_by_id"], name: "index_proposed_actions_on_approved_by_id"
    t.index ["dismissed_by_id"], name: "index_proposed_actions_on_dismissed_by_id"
    t.index ["status"], name: "index_proposed_actions_on_status"
  end

  create_table "user_messages", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "created_by_id", null: false
    t.text "instruction"
    t.string "status"
    t.datetime "frozen_at"
    t.string "llm_provider"
    t.string "llm_model"
    t.text "prompt_snapshot"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.string "error_message"
    t.index ["chat_id"], name: "index_user_messages_on_chat_id"
    t.index ["company_id"], name: "index_user_messages_on_company_id"
    t.index ["created_by_id"], name: "index_user_messages_on_created_by_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_messages", "user_messages"
  add_foreign_key "artifacts", "chats"
  add_foreign_key "artifacts", "companies"
  add_foreign_key "artifacts", "users", column: "created_by_id"
  add_foreign_key "attachments", "companies"
  add_foreign_key "attachments", "users", column: "created_by_id"
  add_foreign_key "chats", "companies"
  add_foreign_key "chats", "users", column: "created_by_id"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "proposed_actions", "ai_messages"
  add_foreign_key "proposed_actions", "users", column: "approved_by_id"
  add_foreign_key "proposed_actions", "users", column: "dismissed_by_id"
  add_foreign_key "user_messages", "chats"
  add_foreign_key "user_messages", "companies"
  add_foreign_key "user_messages", "users", column: "created_by_id"
end
