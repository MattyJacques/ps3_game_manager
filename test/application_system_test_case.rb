require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :rack_test

  # rack_test has no JS runtime, so turbo-rails' stream-source wait hook
  # cannot attach to live cable elements during visit.
  def visit(...)
    page.visit(...)
  end
end
