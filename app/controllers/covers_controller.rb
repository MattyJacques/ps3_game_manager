class CoversController < ApplicationController
  def show
    game = Game.find(params[:id])
    return head :not_found unless Game::TITLE_ID_FORMAT.match?(game.title_id.to_s)

    cover_path = cover_path_for(game.title_id)

    if game.cover_path.present? && File.exist?(cover_path)
      send_data File.binread(cover_path), disposition: "inline", type: "image/jpeg"
    else
      head :not_found
    end
  end

  private

  def cover_path_for(title_id)
    safe_title_id = Game::TITLE_ID_FORMAT.match(title_id.to_s)&.[](0)
    raise ActionController::RoutingError, "Not Found" unless safe_title_id

    Rails.configuration.x.cover_cache_dir.join("#{safe_title_id}.jpg")
  end
end
