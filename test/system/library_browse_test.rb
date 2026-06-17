require "application_system_test_case"

class LibraryBrowseTest < ApplicationSystemTestCase
  test "browsing the library and viewing missing files" do
    Dir.mktmpdir do |dir|
      original_cover_dir = Rails.configuration.x.cover_cache_dir
      Rails.configuration.x.cover_cache_dir = Pathname(dir)
      cover_path = File.join(dir, "BLUS30490.jpg")
      File.binwrite(cover_path, "cover-bytes")
      game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc", cover_path: cover_path)
      MediaFile.create!(path: "/nas/present.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
      MediaFile.create!(path: "/nas/missing.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: false, first_seen_at: Time.current, last_seen_at: Time.current)

      visit root_path
      click_link "Library"

      assert_text "God of War III"
      assert_selector "img[alt='God of War III cover']"

      click_link "Missing"
      assert_text "/nas/missing.iso"
    ensure
      Rails.configuration.x.cover_cache_dir = original_cover_dir
    end
  end
end
