require "application_system_test_case"

class ScanProgressTest < ApplicationSystemTestCase
  test "starting a scan updates the dashboard status" do
    fake_scanner = Object.new
    fake_scanner.define_singleton_method(:call) do |scan:, &block|
      block.call("/nas/BLUS30490-God of War III.iso", 1)
      scan.complete!(files_found: 1, errors_count: 0, summary: "Scanned 1 files with 0 errors")
    end

    original_new = Library::Scanner.method(:new)
    Library::Scanner.define_singleton_method(:new) { fake_scanner }

    begin
      perform_enqueued_jobs do
        visit root_path
        click_button "Scan now"

        assert_text "Scanned 1 files with 0 errors"
      end
    ensure
      Library::Scanner.define_singleton_method(:new, original_new)
    end
  end
end
