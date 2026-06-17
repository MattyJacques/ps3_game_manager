class WishlistItemsController < ApplicationController
  def index
    @wishlist_items = WishlistItem.includes(:game).ordered
  end

  def create
    entry = GameTdb::Catalog.new.lookup(params.fetch(:title_id))
    game = Game.upsert_from_catalog!(title_id: entry.fetch(:title_id), entry: entry)

    WishlistItem.find_or_create_by!(game: game) do |item|
      item.notes = params.fetch(:notes, "")
      item.priority = params.fetch(:priority, 0)
    end

    redirect_to wishlist_items_path, notice: "Wishlist updated"
  end

  def update
    wishlist_item = WishlistItem.find(params[:id])
    wishlist_item.update!(params.require(:wishlist_item).permit(:notes, :priority))

    redirect_to wishlist_items_path, notice: "Wishlist item updated"
  end

  def destroy
    WishlistItem.find(params[:id]).destroy!
    redirect_to wishlist_items_path, notice: "Wishlist item removed"
  end
end
