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

ActiveRecord::Schema[8.1].define(version: 2026_11_25_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "active_storage_db_files", force: :cascade do |t|
    t.string "ref", null: false
    t.binary "data", null: false
    t.datetime "created_at", null: false
    t.index ["ref"], name: "index_active_storage_db_files_on_ref", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "influencers", force: :cascade do |t|
    t.string "name", null: false
    t.string "instagram"
    t.string "tiktok"
    t.string "city"
    t.integer "followers"
    t.string "coupon_code"
    t.integer "feed_goal", default: 1, null: false
    t.integer "stories_goal", default: 4, null: false
    t.integer "tiktok_goal", default: 0, null: false
    t.decimal "cash_value", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "permuta_value", precision: 10, scale: 2, default: "0.0", null: false
    t.boolean "cash_is_permuta", default: false, null: false
    t.date "starts_on"
    t.date "ends_on"
    t.string "pix_key"
    t.string "phone"
    t.text "notes"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((instagram)::text)", name: "index_influencers_on_lower_instagram", unique: true, where: "(instagram IS NOT NULL)"
    t.index ["coupon_code"], name: "index_influencers_on_coupon_code", unique: true, where: "(coupon_code IS NOT NULL)"
  end

  create_table "monthly_statements", force: :cascade do |t|
    t.bigint "influencer_id", null: false
    t.date "month", null: false
    t.decimal "amount_paid", precision: 10, scale: 2
    t.string "payment_status", default: "open", null: false
    t.datetime "paid_at"
    t.bigint "paid_by_id"
    t.text "payment_note"
    t.string "coupon_status", default: "none", null: false
    t.integer "coupon_usage_limit"
    t.datetime "coupon_incremented_at"
    t.text "coupon_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "review_status", default: "open", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.text "review_note"
    t.decimal "amount_payable", precision: 10, scale: 2
    t.date "due_on"
    t.index ["influencer_id", "month"], name: "index_monthly_statements_on_influencer_id_and_month", unique: true
    t.index ["influencer_id"], name: "index_monthly_statements_on_influencer_id"
    t.index ["paid_by_id"], name: "index_monthly_statements_on_paid_by_id"
    t.index ["review_status"], name: "index_monthly_statements_on_review_status"
    t.index ["reviewed_by_id"], name: "index_monthly_statements_on_reviewed_by_id"
  end

  create_table "proofs", force: :cascade do |t|
    t.bigint "influencer_id", null: false
    t.bigint "submitted_by_id"
    t.bigint "reviewed_by_id"
    t.date "month", null: false
    t.string "kind", null: false
    t.integer "quantity", default: 1, null: false
    t.date "posted_on"
    t.string "link"
    t.text "description"
    t.string "status", default: "pending", null: false
    t.text "review_note"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["influencer_id", "month", "kind"], name: "index_proofs_on_influencer_id_and_month_and_kind"
    t.index ["influencer_id"], name: "index_proofs_on_influencer_id"
    t.index ["reviewed_by_id"], name: "index_proofs_on_reviewed_by_id"
    t.index ["status"], name: "index_proofs_on_status"
    t.index ["submitted_by_id"], name: "index_proofs_on_submitted_by_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "role", default: "influencer", null: false
    t.bigint "influencer_id"
    t.datetime "access_sent_at"
    t.datetime "invited_at"
    t.datetime "activated_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["influencer_id"], name: "index_users_on_influencer_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "monthly_statements", "influencers"
  add_foreign_key "monthly_statements", "users", column: "paid_by_id"
  add_foreign_key "monthly_statements", "users", column: "reviewed_by_id"
  add_foreign_key "proofs", "influencers"
  add_foreign_key "proofs", "users", column: "reviewed_by_id"
  add_foreign_key "proofs", "users", column: "submitted_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "influencers"
end
