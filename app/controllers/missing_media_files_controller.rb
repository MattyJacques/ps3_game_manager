class MissingMediaFilesController < ApplicationController
  def index
    @media_files = MediaFile.missing.includes(:game).order(:path)
  end
end
