require "test_helper"

class MediaFileTest < ActiveSupport::TestCase
  test "unidentified scope returns files without a title id" do
    unidentified = MediaFile.create!(path: "/nas/Unknown.iso", file_format: "iso", byte_size: 1, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    identified = MediaFile.create!(path: "/nas/Known.iso", file_format: "iso", byte_size: 1, title_id: "BLUS30490", present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    assert_includes MediaFile.unidentified, unidentified
    assert_not_includes MediaFile.unidentified, identified
  end
end
