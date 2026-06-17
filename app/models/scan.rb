class Scan < ApplicationRecord
  validates :status, :started_at, :summary, presence: true
  validates :status, inclusion: { in: %w[running completed failed] }

  scope :recent_first, -> { order(started_at: :desc) }

  def complete!(files_found:, errors_count:, summary:)
    update!(
      status: "completed",
      finished_at: Time.current,
      files_found: files_found,
      errors_count: errors_count,
      summary: summary
    )
  end

  def fail!(summary:)
    update!(status: "failed", finished_at: Time.current, summary: summary)
  end
end
