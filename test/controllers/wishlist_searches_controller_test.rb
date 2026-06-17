require "test_helper"

class WishlistSearchesControllerTest < ActionDispatch::IntegrationTest
  test "returns matching GameTDB results" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:search) do |_query|
      [{ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }]
    end

    original_new = GameTdb::Catalog.method(:new)
    GameTdb::Catalog.define_singleton_method(:new) { fake_catalog }

    begin
      get wishlist_searches_url, params: { q: "war" }
    ensure
      GameTdb::Catalog.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_includes @response.body, "God of War III"
  end
end
