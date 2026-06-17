class UnidentifiedMediaFilesController < ApplicationController
  def index
    @media_files = MediaFile.unidentified.order(:path)
  end
end
