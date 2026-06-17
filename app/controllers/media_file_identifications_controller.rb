class MediaFileIdentificationsController < ApplicationController
  def update
    media_file = MediaFile.find(params[:id])
    title_id = params.require(:media_file).fetch(:title_id)
    entry = GameTdb::Catalog.new.lookup(title_id)

    game = entry ? Game.upsert_from_catalog!(title_id: title_id, entry: entry) : nil
    media_file.update!(title_id: title_id, game: game)

    redirect_to unidentified_media_files_path, notice: "File updated"
  end
end
