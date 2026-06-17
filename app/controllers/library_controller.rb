class LibraryController < ApplicationController
  def index
    scope = Game.owned.includes(:media_files).order(:name)
    scope = scope.where(region: params[:region]) if params[:region].present?
    scope = scope.where("games.name LIKE :q OR games.title_id LIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    if params[:format].present?
      scope = scope.joins(:media_files).merge(MediaFile.present_now.where(file_format: params[:format]))
    end

    @games = scope.distinct
  end
end
