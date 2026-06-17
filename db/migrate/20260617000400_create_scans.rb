class CreateScans < ActiveRecord::Migration[8.1]
  def change
    create_table :scans do |t|
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :files_found, null: false, default: 0
      t.integer :errors_count, null: false, default: 0
      t.string :summary, null: false, default: ""

      t.timestamps
    end

    add_index :scans, :status
    add_index :scans, :started_at
  end
end
