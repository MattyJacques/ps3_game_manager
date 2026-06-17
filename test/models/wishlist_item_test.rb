require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  test "owned? returns true when the game has a present media file" do
    game = Game.create!(title_id: "BLUS30490", name: "Wanted", region: "US", kind: "disc")
    wishlist_item = WishlistItem.create!(game: game, notes: "keep an eye out", priority: 3)

    MediaFile.create!(path: "/nas/Wanted.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    assert wishlist_item.owned?
  end
end
