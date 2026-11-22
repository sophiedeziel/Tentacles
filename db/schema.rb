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

ActiveRecord::Schema[8.1].define(version: 2026_11_22_120000) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
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

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "dashboard_sections", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dashboard_widgets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "dashboard_section_id", null: false
    t.string "type", null: false
    t.integer "width_units", null: false
    t.integer "height_units", null: false
    t.integer "position", null: false
    t.bigint "printer_id"
    t.json "options", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_section_id", "position"], name: "index_dashboard_widgets_on_dashboard_section_id_and_position"
    t.index ["dashboard_section_id"], name: "index_dashboard_widgets_on_dashboard_section_id"
    t.index ["printer_id"], name: "index_dashboard_widgets_on_printer_id"
  end

  create_table "file_labels", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "file_record_id", null: false
    t.bigint "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_record_id"], name: "index_file_labels_on_file_record_id"
    t.index ["label_id"], name: "index_file_labels_on_label_id"
  end

  create_table "file_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_not_archived", default: true
    t.datetime "archived_at", precision: nil
  end

  create_table "labels", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "printer_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.bigint "printer_id", null: false
    t.integer "executable_id", null: false
    t.string "executable_type", null: false
    t.string "status", default: "enqueued", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "progress", default: 0.0, null: false
    t.index ["printer_id", "status", "created_at"], name: "index_printer_jobs_on_printer_id_and_status_and_created_at"
  end

  create_table "printers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_seen_at"
    t.string "backend", default: "octoprint", null: false
    t.string "uri"
    t.string "username"
    t.text "secret"
    t.boolean "favorite", default: false, null: false
    t.string "brand", limit: 100
    t.string "model", limit: 100
    t.string "firmware", limit: 100
    t.string "firmware_version", limit: 50
    t.decimal "build_volume_x", precision: 6, scale: 1
    t.decimal "build_volume_y", precision: 6, scale: 1
    t.decimal "build_volume_z", precision: 6, scale: 1
    t.decimal "build_diameter", precision: 6, scale: 1
    t.string "bed_shape"
    t.integer "extruders"
    t.decimal "nozzle_diameter", precision: 4, scale: 2
    t.integer "max_hotend_temp"
    t.integer "max_bed_temp"
    t.boolean "heated_bed"
    t.boolean "heated_chamber"
    t.boolean "webcam"
    t.json "materials"
    t.datetime "specs_filled_at"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "dashboard_widgets", "dashboard_sections", on_delete: :cascade
  add_foreign_key "dashboard_widgets", "printers"
  add_foreign_key "file_labels", "file_records"
  add_foreign_key "file_labels", "labels"
  add_foreign_key "printer_jobs", "printers"
end
