class Game < ApplicationRecord
  TITLE_ID_FORMAT = /\A[A-Z]{4}\d{5}\z/

  has_many :media_files, dependent: :nullify
  has_many :wishlist_items, dependent: :destroy

  validates :title_id, :name, :region, :kind, presence: true
  validates :title_id, uniqueness: true
  validates :title_id, format: { with: TITLE_ID_FORMAT }
  validates :kind, inclusion: { in: %w[disc psn] }

  scope :owned, -> { joins(:media_files).merge(MediaFile.present_now).distinct }

  def self.upsert_from_catalog!(title_id:, entry:)
    game = find_or_initialize_by(title_id: title_id)
    game.name = entry.fetch(:name)
    game.region = entry.fetch(:region)
    game.kind = entry.fetch(:kind)
    game.save!
    game
  end
end
