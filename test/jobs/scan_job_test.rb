require "test_helper"

class ScanJobTest < ActiveJob::TestCase
  test "marks the scan complete" do
    scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
    fake_scanner = Object.new
    fake_scanner.define_singleton_method(:call) do |scan:, &|
      scan.complete!(files_found: 2, errors_count: 0, summary: "Done")
    end

    original_new = Library::Scanner.method(:new)
    Library::Scanner.define_singleton_method(:new) { fake_scanner }

    begin
      perform_enqueued_jobs { ScanJob.perform_later(scan.id) }
    ensure
      Library::Scanner.define_singleton_method(:new, original_new)
    end

    assert_equal "completed", scan.reload.status
    assert_equal 2, scan.files_found
  end
end
