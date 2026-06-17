require "test_helper"

class GameTdbCoverCacheTest < ActiveSupport::TestCase
  test "downloads and stores a cover once" do
    Dir.mktmpdir do |dir|
      cache = GameTdb::CoverCache.new(cache_dir: Pathname(dir), fetcher: ->(_url) { "image-bytes" })

      path = cache.fetch!(title_id: "BLUS30490", region: "US")

      assert_equal Pathname(dir).join("BLUS30490.jpg"), path
      assert_equal "image-bytes", File.binread(path)
    end
  end
end
