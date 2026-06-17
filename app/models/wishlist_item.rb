class WishlistItem < ApplicationRecord
  belongs_to :game

  validates :priority, numericality: { only_integer: true }

  scope :ordered, -> { order(priority: :desc, created_at: :asc) }

  def owned?
    game.media_files.present_now.exists?
  end
end
