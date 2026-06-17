class CreateWishlistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :wishlist_items do |t|
      t.references :game, null: false, foreign_key: true
      t.text :notes, null: false, default: ""
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    change_column_default :wishlist_items, :notes, from: nil, to: ""
    add_index :wishlist_items, :priority
  end
end
