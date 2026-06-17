require "test_helper"

class LibraryScannerTest < ActiveSupport::TestCase
  FakeCatalog = Struct.new(:entries) do
    def lookup(title_id)
      entries[title_id]
    end
  end

    FakeCoverCache = Struct.new(:downloads) do
      def fetch!(title_id:, region:)
      downloads << [ title_id, region ]
        Pathname("/covers/#{title_id}.jpg")
      end
    end

  test "creates media files, links games, and marks unseen files missing" do
    missing_game = Game.create!(title_id: "BLES00682", name: "Old", region: "EU", kind: "disc")
    MediaFile.create!(path: "/nas/old.pkg", file_format: "pkg", byte_size: 1, title_id: missing_game.title_id, game: missing_game, present: true, first_seen_at: 2.days.ago, last_seen_at: 2.days.ago)

    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "BLUS30490-God of War III.iso"), "iso")
      File.binwrite(File.join(dir, "mystery.pkg"), "\x00" * 32 + "EP9000-BLES00682_00-GAME00000000001" + "\x00" * 32)

      catalog = FakeCatalog.new({
        "BLUS30490" => { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" },
        "BLES00682" => { title_id: "BLES00682", name: "Demon's Souls", region: "EU", kind: "disc" }
      })

      scanner = Library::Scanner.new(
        nas_path: dir,
        extractor: TitleId::Extractor.new,
        catalog: catalog,
        cover_cache: FakeCoverCache.new([])
      )

      scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
      scanner.call(scan: scan)

      assert_equal 2, MediaFile.present_now.count
      assert_equal 1, MediaFile.missing.count
      assert_equal [ "BLES00682", "BLUS30490" ], Game.order(:title_id).pluck(:title_id)
      assert_equal "completed", scan.reload.status
    end
  end

  test "continues scanning when cover downloads fail" do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "BLUS30490-God of War III.iso"), "iso")

      catalog = FakeCatalog.new({
        "BLUS30490" => { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
      })
      failing_cover_cache = Object.new
      failing_cover_cache.define_singleton_method(:fetch!) do |**|
        raise SocketError, "art host offline"
      end

      scanner = Library::Scanner.new(
        nas_path: dir,
        extractor: TitleId::Extractor.new,
        catalog: catalog,
        cover_cache: failing_cover_cache
      )

      scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
      scanner.call(scan: scan)

      assert_equal "completed", scan.reload.status
      assert_equal "BLUS30490", MediaFile.find_by!(path: File.join(dir, "BLUS30490-God of War III.iso")).title_id
      assert_nil Game.find_by!(title_id: "BLUS30490").cover_path
    end
  end
end
