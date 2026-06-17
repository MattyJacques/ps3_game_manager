require "test_helper"

class MediaFileIdentificationsControllerTest < ActionDispatch::IntegrationTest
  test "updates an unidentified file with a manual title id" do
    media_file = MediaFile.create!(path: "/nas/unknown.iso", file_format: "iso", byte_size: 1, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    original_new = GameTdb::Catalog.method(:new)
    GameTdb::Catalog.define_singleton_method(:new) { fake_catalog }

    begin
      patch media_file_identification_url(media_file), params: { media_file: { title_id: "BLUS30490" } }
    ensure
      GameTdb::Catalog.define_singleton_method(:new, original_new)
    end

    assert_redirected_to unidentified_media_files_url
    assert_equal "BLUS30490", media_file.reload.title_id
    assert_equal "God of War III", media_file.game.name
  end
end
