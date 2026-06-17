require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "owned scope only returns games with present media files" do
    owned = Game.create!(title_id: "BLUS30490", name: "Wanted", region: "US", kind: "disc")
    missing = Game.create!(title_id: "BLES00682", name: "Missing", region: "EU", kind: "disc")

    MediaFile.create!(path: "/nas/Wanted.iso", file_format: "iso", byte_size: 1, title_id: owned.title_id, game: owned, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    MediaFile.create!(path: "/nas/Missing.iso", file_format: "iso", byte_size: 1, title_id: missing.title_id, game: missing, present: false, first_seen_at: Time.current, last_seen_at: Time.current)

    assert_equal [ owned ], Game.owned.order(:title_id).to_a
  end
end
