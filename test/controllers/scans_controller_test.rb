require "test_helper"

class ScansControllerTest < ActionDispatch::IntegrationTest
  test "queues a scan and redirects home" do
    assert_enqueued_with(job: ScanJob) do
      post scans_url
    end

    assert_redirected_to root_url
    assert_equal "running", Scan.order(:created_at).last.status
  end
end
