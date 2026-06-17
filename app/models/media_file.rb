class MediaFile < ApplicationRecord
  belongs_to :game, optional: true

  validates :path, :file_format, :byte_size, :first_seen_at, :last_seen_at, presence: true
  validates :path, uniqueness: true
  validates :file_format, inclusion: { in: %w[iso pkg] }

  scope :present_now, -> { where(present: true) }
  scope :missing, -> { where(present: false) }
  scope :unidentified, -> { present_now.where(title_id: nil) }
end
