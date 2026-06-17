require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  test "creates a wishlist item from a GameTDB title id" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    original_new = GameTdb::Catalog.method(:new)
    GameTdb::Catalog.define_singleton_method(:new) { fake_catalog }

    begin
      post wishlist_items_url, params: { title_id: "BLUS30490", notes: "look for a clean rip", priority: 5 }
    ensure
      GameTdb::Catalog.define_singleton_method(:new, original_new)
    end

    item = WishlistItem.order(:created_at).last
    assert_redirected_to wishlist_items_url
    assert_equal "BLUS30490", item.game.title_id
    assert_equal 5, item.priority
  end
end
