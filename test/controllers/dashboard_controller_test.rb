require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows the dashboard shell" do
    get "/"

    assert_response :success
    assert_select "h1", "PS3 Game Manager"
    assert_select "button", "Scan now"
    assert_select "a", "Library"
    assert_select "a", "Wishlist"
  end
end
