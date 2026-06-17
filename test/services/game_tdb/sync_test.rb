require "test_helper"

class GameTdbSyncTest < ActiveSupport::TestCase
  test "keeps using the cached xml when refresh fails" do
    Dir.mktmpdir do |dir|
      xml_path = Pathname(dir).join("ps3tdb.xml")
      xml_path.write("cached-data")
      stale_time = 2.days.ago.to_time
      xml_path.utime(stale_time, stale_time)

      sync = GameTdb::Sync.new(
        cache_dir: dir,
        refresh_hours: 1,
        fetcher: ->(_uri) { raise SocketError, "offline" }
      )

      assert_equal xml_path, sync.ensure_current!
      assert_equal "cached-data", xml_path.read
    end
  end
end
