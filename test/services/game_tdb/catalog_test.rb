require "test_helper"

class GameTdbCatalogTest < ActiveSupport::TestCase
  test "looks up a title by id and searches by name" do
    Dir.mktmpdir do |dir|
      xml_path = File.join(dir, "ps3tdb.xml")
      File.write(xml_path, <<~XML)
        <datafile>
          <game name="God of War III">
            <id>BLUS30490</id>
            <region>US</region>
            <type>disc</type>
            <locale lang="EN">
              <title>God of War III</title>
            </locale>
          </game>
          <game name="Demon's Souls">
            <id>BLES00932</id>
            <region>EU</region>
            <type>disc</type>
            <locale lang="EN">
              <title>Demon's Souls</title>
            </locale>
          </game>
        </datafile>
      XML

      catalog = GameTdb::Catalog.new(xml_path: xml_path)

      assert_equal({ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }, catalog.lookup("BLUS30490"))
      assert_equal ["Demon's Souls"], catalog.search("souls").map { |entry| entry.fetch(:name) }
    end
  end
end
