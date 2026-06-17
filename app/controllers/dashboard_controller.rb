class DashboardController < ApplicationController
  def index
    @last_scan = Scan.recent_first.first
    @owned_count = Game.owned.count
    @wishlist_count = WishlistItem.count
    @missing_count = MediaFile.missing.count
    @unidentified_count = MediaFile.unidentified.count
  end
end
