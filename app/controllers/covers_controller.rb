class CoversController < ApplicationController
  def show
    game = Game.find(params[:id])

    if game.cover_path.present? && File.exist?(game.cover_path)
      send_file game.cover_path, disposition: "inline", type: "image/jpeg"
    else
      head :not_found
    end
  end
end
