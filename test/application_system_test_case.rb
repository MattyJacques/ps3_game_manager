require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :rack_test
  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  # rack_test has no JS runtime, so turbo-rails' stream-source wait hook
  # cannot attach to live cable elements during visit.
  def visit(...)
    page.visit(...)
  end

  teardown do
    WishlistItem.delete_all
    MediaFile.delete_all
    Scan.delete_all
    Game.delete_all
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
