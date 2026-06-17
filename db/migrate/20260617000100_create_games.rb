class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :title_id, null: false
      t.string :name, null: false
      t.string :region, null: false
      t.string :kind, null: false
      t.string :cover_path

      t.timestamps
    end

    add_index :games, :title_id, unique: true
    add_index :games, :name
  end
end
