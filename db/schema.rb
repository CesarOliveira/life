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

ActiveRecord::Schema[8.1].define(version: 2026_07_08_111224) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "api_token"
    t.datetime "created_at", null: false
    t.integer "height_cm"
    t.string "join_code"
    t.string "locale", default: "pt-BR", null: false
    t.string "name", null: false
    t.bigint "owner_id"
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_accounts_on_api_token", unique: true
    t.index ["join_code"], name: "index_accounts_on_join_code", unique: true
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
  end

  create_table "app_usages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "bundle_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "device", default: "iphone", null: false
    t.string "name"
    t.integer "seconds", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "device", "date", "bundle_id"], name: "idx_app_usages_unique", unique: true
    t.index ["account_id"], name: "index_app_usages_on_account_id"
  end

  create_table "connectors", force: :cascade do |t|
    t.text "access_token"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "last_error"
    t.integer "last_points", default: 0, null: false
    t.datetime "last_synced_at"
    t.jsonb "settings", default: {}, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind"], name: "index_connectors_on_account_id_and_kind", unique: true
    t.index ["account_id"], name: "index_connectors_on_account_id"
  end

  create_table "exam_extractions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "cost_usd", precision: 10, scale: 6, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms", default: 0, null: false
    t.string "error"
    t.integer "file_bytes", default: 0, null: false
    t.integer "input_tokens", default: 0, null: false
    t.string "models_used", default: "", null: false
    t.integer "output_tokens", default: 0, null: false
    t.integer "rows_count", default: 0, null: false
    t.string "status", default: "success", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_exam_extractions_on_account_id"
    t.index ["created_at"], name: "index_exam_extractions_on_created_at"
  end

  create_table "exam_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description_en"
    t.text "description_pt"
    t.boolean "favorite", default: false, null: false
    t.string "key", null: false
    t.string "name_en", null: false
    t.string "name_pt", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_exam_groups_on_key", unique: true
  end

  create_table "exam_results", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "exam_type_id", null: false
    t.date "measured_on", null: false
    t.decimal "ref_high", precision: 12, scale: 3
    t.decimal "ref_low", precision: 12, scale: 3
    t.string "source", default: "manual", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 12, scale: 3, null: false
    t.index ["account_id", "exam_type_id", "measured_on"], name: "idx_exam_results_unique", unique: true
    t.index ["account_id"], name: "index_exam_results_on_account_id"
    t.index ["exam_type_id"], name: "index_exam_results_on_exam_type_id"
  end

  create_table "exam_types", force: :cascade do |t|
    t.string "aliases", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description_en"
    t.text "description_pt"
    t.bigint "exam_group_id", null: false
    t.string "key", null: false
    t.string "name_en", null: false
    t.string "name_pt", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["exam_group_id"], name: "index_exam_types_on_exam_group_id"
    t.index ["key"], name: "index_exam_types_on_key", unique: true
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "achieved_on"
    t.datetime "created_at", null: false
    t.date "deadline"
    t.string "metric_key", null: false
    t.string "name", null: false
    t.decimal "start_value", precision: 12, scale: 3
    t.decimal "target_value", precision: 12, scale: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_goals_on_account_id"
  end

  create_table "habit_categories", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_habit_categories_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_habit_categories_on_account_id"
  end

  create_table "habit_checks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.bigint "habit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["habit_id", "date"], name: "index_habit_checks_on_habit_id_and_date", unique: true
    t.index ["habit_id"], name: "index_habit_checks_on_habit_id"
  end

  create_table "habits", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "app_bundle_ids", default: [], null: false, array: true
    t.boolean "auto", default: false, null: false
    t.string "color", default: "#6366f1", null: false
    t.string "comparator"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "frequency", default: "weekly_days", null: false
    t.bigint "habit_category_id", null: false
    t.string "metric_key"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.decimal "threshold_value", precision: 12, scale: 3
    t.datetime "updated_at", null: false
    t.integer "weekdays", default: [0, 1, 2, 3, 4, 5, 6], null: false, array: true
    t.integer "weekly_target"
    t.index ["account_id", "active"], name: "index_habits_on_account_id_and_active"
    t.index ["account_id"], name: "index_habits_on_account_id"
    t.index ["habit_category_id"], name: "index_habits_on_habit_category_id"
  end

  create_table "ingestion_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.integer "byte_size", default: 0, null: false
    t.string "client_version"
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.string "ip"
    t.jsonb "query", default: {}, null: false
    t.text "raw_body"
    t.jsonb "result", default: {}, null: false
    t.integer "status"
    t.index ["account_id"], name: "index_ingestion_logs_on_account_id"
    t.index ["created_at"], name: "index_ingestion_logs_on_created_at"
    t.index ["endpoint", "created_at"], name: "index_ingestion_logs_on_endpoint_and_created_at"
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "category", default: "health", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.date "measured_on", null: false
    t.decimal "ref_high", precision: 12, scale: 3
    t.decimal "ref_low", precision: 12, scale: 3
    t.string "source", default: "manual", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 12, scale: 3, null: false
    t.index ["account_id", "category"], name: "index_measurements_on_account_id_and_category"
    t.index ["account_id", "key", "measured_on"], name: "idx_measurements_unique", unique: true
    t.index ["account_id"], name: "index_measurements_on_account_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["status"], name: "index_memberships_on_status"
    t.index ["user_id", "account_id"], name: "index_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "roles_users", id: false, force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "user_id", null: false
    t.index ["role_id", "user_id"], name: "index_roles_users_on_role_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_roles_users_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "weight_entries", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 5, scale: 2, null: false
    t.index ["account_id", "date"], name: "index_weight_entries_on_account_id_and_date", unique: true
    t.index ["account_id"], name: "index_weight_entries_on_account_id"
  end

  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "app_usages", "accounts"
  add_foreign_key "connectors", "accounts"
  add_foreign_key "exam_extractions", "accounts"
  add_foreign_key "exam_results", "accounts"
  add_foreign_key "exam_results", "exam_types"
  add_foreign_key "exam_types", "exam_groups"
  add_foreign_key "goals", "accounts"
  add_foreign_key "habit_categories", "accounts"
  add_foreign_key "habit_checks", "habits"
  add_foreign_key "habits", "accounts"
  add_foreign_key "habits", "habit_categories"
  add_foreign_key "ingestion_logs", "accounts"
  add_foreign_key "measurements", "accounts"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "weight_entries", "accounts"
end
