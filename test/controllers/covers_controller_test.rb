require "test_helper"

class CoversControllerTest < ActionDispatch::IntegrationTest
  test "streams a cached cover from disk" do
    Dir.mktmpdir do |dir|
      cover_path = File.join(dir, "BLUS30490.jpg")
      File.binwrite(cover_path, "cover-bytes")
      game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc", cover_path: cover_path)

      get cover_url(game)

      assert_response :success
      assert_equal "cover-bytes", @response.body
    end
  end
end
