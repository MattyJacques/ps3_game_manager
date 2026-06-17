require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  test "filters the owned library by region" do
    us_game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc")
    eu_game = Game.create!(title_id: "BLES00682", name: "Demon's Souls", region: "EU", kind: "disc")

    MediaFile.create!(path: "/nas/us.iso", file_format: "iso", byte_size: 1, title_id: us_game.title_id, game: us_game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    MediaFile.create!(path: "/nas/eu.iso", file_format: "iso", byte_size: 1, title_id: eu_game.title_id, game: eu_game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    get library_index_url, params: { region: "US" }

    assert_response :success
    assert_select "h2", "God of War III"
    assert_select "h2", text: "Demon's Souls", count: 0
  end
end
