require "application_system_test_case"

class WishlistManagementTest < ApplicationSystemTestCase
  test "searching and adding a wishlist entry" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:search) do |_query|
      [{ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }]
    end
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    original_new = GameTdb::Catalog.method(:new)
    GameTdb::Catalog.define_singleton_method(:new) { fake_catalog }

    begin
      visit wishlist_items_path
      fill_in "q", with: "war"
      click_button "Search"
      click_button "Add God of War III"

      assert_text "God of War III"
    ensure
      GameTdb::Catalog.define_singleton_method(:new, original_new)
    end
  end
end
