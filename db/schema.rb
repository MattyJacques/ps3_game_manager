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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_000400) do
  create_table "games", force: :cascade do |t|
    t.string "cover_path"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.string "region", null: false
    t.string "title_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_games_on_name"
    t.index ["title_id"], name: "index_games_on_title_id", unique: true
  end

  create_table "media_files", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.datetime "created_at", null: false
    t.string "file_format", null: false
    t.datetime "first_seen_at", null: false
    t.integer "game_id"
    t.datetime "last_seen_at", null: false
    t.string "path", null: false
    t.boolean "present", default: true, null: false
    t.string "title_id"
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_media_files_on_game_id"
    t.index ["path"], name: "index_media_files_on_path", unique: true
    t.index ["present"], name: "index_media_files_on_present"
    t.index ["title_id"], name: "index_media_files_on_title_id"
  end

  create_table "scans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "errors_count", default: 0, null: false
    t.integer "files_found", default: 0, null: false
    t.datetime "finished_at"
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.string "summary", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_scans_on_started_at"
    t.index ["status"], name: "index_scans_on_status"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_id", null: false
    t.text "notes", default: "", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_wishlist_items_on_game_id"
    t.index ["priority"], name: "index_wishlist_items_on_priority"
  end

  add_foreign_key "media_files", "games"
  add_foreign_key "wishlist_items", "games"
end
