require "test_helper"

class TitleIdExtractorTest < ActiveSupport::TestCase
  test "extracts the title id from the filename" do
    extractor = TitleId::Extractor.new

    assert_equal "BLUS30490", extractor.call("/nas/Action/BLUS30490-God of War III.iso")
  end

  test "extracts the title id from the parent folder when the filename is generic" do
    extractor = TitleId::Extractor.new

    assert_equal "BLES00682", extractor.call("/nas/BLES00682/Game Backup.iso")
  end

  test "falls back to the PKG header content id" do
    Dir.mktmpdir do |dir|
      pkg_path = File.join(dir, "mystery.pkg")
      File.binwrite(pkg_path, "\x00" * 32 + "EP9000-BLES00682_00-GAME00000000001" + "\x00" * 32)

      extractor = TitleId::Extractor.new
      assert_equal "BLES00682", extractor.call(pkg_path)
    end
  end
end
