class CreateMediaFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :media_files do |t|
      t.string :path, null: false
      t.string :file_format, null: false
      t.bigint :byte_size, null: false
      t.string :title_id
      t.references :game, foreign_key: true
      t.boolean :present, null: false, default: true
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :media_files, :path, unique: true
    add_index :media_files, :title_id
    add_index :media_files, :present
  end
end
